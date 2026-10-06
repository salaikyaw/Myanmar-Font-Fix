'use strict';
// font-menu.cjs - flicker-free interactive menu backend for Select-FontMenu.ps1
// Usage: node font-menu.cjs --items '[{"Key":"1","Label":"..."},...]'
//   Renders in place (ANSI cursor reposition, no Clear-Host), supports:
//   Up/Down/Home/End, digits+letters buffer, Enter, Esc, and mouse clicks
//   (SGR 1006 / normal 1000 / rxvt encodings). Prints the chosen Key on stdout
//   and --result-file (if given) at finish, then exits 0. 'Q' on Esc.
// Selftest: node font-menu.cjs --selftest  (exit 0 on pass, 1 on fail)

function parseCliItems(argv) {
  var i = argv.indexOf('--items');
  if (i < 0 || i + 1 >= argv.length) return null;
  try {
    var parsed = JSON.parse(argv[i + 1]);
    if (!Array.isArray(parsed) || parsed.length === 0) return null;
    for (var k = 0; k < parsed.length; k++) {
      if (!parsed[k] || typeof parsed[k].Key !== 'string' || typeof parsed[k].Label !== 'string') return null;
    }
    return parsed;
  } catch (e) { return null; }
}

// Parse one mouse report whose payload starts at buf[at]. Returns {consumed,index,code}
// or null. index is the clicked item row on a RELEASE (button-and-release pair),
// or -2 for press/motion/unknown reports (consume silently, never a click).
// Supports SGR ('<' seq 'M'/'m'), X10/normal 'ESC [ M b x y', and rxvt encoding.
function parseMouse(buf, at, firstRow, count) {
  function rowOf(col, row) {
    if (row < firstRow || row >= firstRow + count || col < 1) return -1;
    return row - firstRow;
  }
  if (buf[at] === 60) { // '<' SGR: ESC [ < b ; x ; y (M|m)
    var j = at + 1, btnStr = '', xStr = '', yStr = '', stage = 0, release = false;
    for (; j < buf.length; j++) {
      var ch = buf[j];
      if (stage === 0) { if (ch >= 48 && ch <= 57) btnStr += String.fromCharCode(ch); else if (ch === 59) stage = 1; else return null; }
      else if (stage === 1) { if (ch >= 48 && ch <= 57) xStr += String.fromCharCode(ch); else if (ch === 59) stage = 2; else return null; }
      else if (stage === 2) { if (ch >= 48 && ch <= 57) yStr += String.fromCharCode(ch); else if (ch === 77 || ch === 109) { release = ch === 109; break; } else return null; }
    }
    if (stage !== 2 || j >= buf.length) return null;
    var btn = parseInt(btnStr, 10), x = parseInt(xStr, 10), y = parseInt(yStr, 10);
    if (!isFinite(btn) || !isFinite(x) || !isFinite(y)) return null;
    return { consumed: j + 1 - at, index: release ? rowOf(x, y) : -2, code: (btn & 64) ? 1 : 0 };
  }
  var b1 = buf[at], b2 = buf[at + 1], b3 = buf[at + 2];
  if (b2 === undefined || b3 === undefined) return null;
  if (!(b1 >= 32 && b1 < 64) && !(b1 >= 96 && b1 < 128)) return null; // X10 or rxvt button byte
  var base = b1 % 32;
  var isRelease = (base & 3) === 3;
  var idx = isRelease ? rowOf(b2 - 32, b3 - 32) : -2;
  return { consumed: 3, index: idx, code: ((base & 64) ? 1 : 0) };
}

// Translate one stdin chunk into actions.
// out: {enter,esc,backspace,chars:[],up,down,home,end,clicks:[]}
function parseInput(buf, firstRow, count) {
  var out = { enter: false, esc: false, backspace: false, chars: [], up: false, down: false, home: false, end: false, clicks: [] };
  var i = 0;
  while (i < buf.length) {
    var b = buf[i];
    if (b === 27) { // ESC
      if (i + 1 >= buf.length) { out.esc = true; i++; continue; }
      if (buf[i + 1] === 91) { // CSI [
        if (i + 2 >= buf.length) { i += 2; continue; } // lone bracket: drop
        var c = buf[i + 2];
        if (c === 65) { out.up = true; i += 3; continue; }
        if (c === 66) { out.down = true; i += 3; continue; }
        if (c === 72) { out.home = true; i += 3; continue; } // CSI H
        if (c === 70) { out.end = true; i += 3; continue; }  // CSI F
        if (c === 79 && i + 3 < buf.length) { // SS3: ESC O H / ESC O F
          if (buf[i + 3] === 72) { out.home = true; i += 4; continue; }
          if (buf[i + 3] === 70) { out.end = true; i += 4; continue; }
        }
        if (c === 77) { // ESC [ M b x y : X10/normal-mode mouse report
          var mx = parseMouse(buf, i + 3, firstRow, count);
          if (mx) { if (mx.index >= 0 && mx.code === 0) out.clicks.push(mx.index); i += 3 + mx.consumed; continue; }
          i += 3; continue;
        }
        if (c === 60 || (c >= 32 && c < 64) || (c >= 96 && c < 128)) { // possible SGR mouse report
          var m = parseMouse(buf, i + 2, firstRow, count);
          if (m) {
            if (m.index >= 0 && m.code === 0) out.clicks.push(m.index);
            i += 2 + m.consumed; continue;
          }
        }
        i += 3; continue; // unknown CSI: drop 3 bytes
      }
      if (buf[i + 1] === 79) { // SS3: ESC O H / ESC O F (H/F is buf[i+2], not buf[i+3])
        if (i + 2 < buf.length && buf[i + 2] === 72) { out.home = true; i += 3; continue; }
        if (i + 2 < buf.length && buf[i + 2] === 70) { out.end = true; i += 3; continue; }
        i += 2; continue;
      }
      i += 2; continue; // Alt+key etc: drop
    }
    if (b === 13 || b === 10) { out.enter = true; i++; continue; } // Enter
    if (b === 8 || b === 127) { out.backspace = true; i++; continue; }
    if (b === 9) { i++; continue; } // Tab: ignore
    if (b >= 32) { // printable
      var end = i;
      while (end < buf.length && buf[end] >= 32) end++;
      out.chars.push(buf.slice(i, end).toString('utf8'));
      i = end; continue;
    }
    i++; // other control byte: drop
  }
  return out;
}

function buildFrame(items, index, buffer, pageSize, width, title, subtitle, escapeText) {
  var esc = String.fromCharCode(27);
  var lines = [];
  lines.push(' ' + title);
  lines.push(' ' + subtitle);
  lines.push(' Esc: ' + escapeText + '   Home/End: first/last   Mouse: click a row');
  lines.push('');
  var first = Math.floor(index / pageSize) * pageSize;
  var last = Math.min(items.length - 1, first + pageSize - 1);
  for (var i = first; i <= last; i++) {
    var prefix = (i === index) ? ' > ' : '   ';
    var line = prefix + '[' + items[i].Key + '] ' + items[i].Label;
    if (line.length > width) line = line.substring(0, width);
    while (line.length < width) line += ' ';
    if (i === index) line = esc + '[7m' + line + esc + '[0m';
    lines.push(line);
  }
  lines.push('');
  lines.push(' Typed: ' + buffer + '   |   Item ' + (index + 1) + '/' + items.length);
  return lines;
}

function selftest() {
  function eq(a, b, msg) { if (a !== b) { console.error('FAIL: ' + msg + ' got=' + JSON.stringify(a) + ' want=' + JSON.stringify(b)); return false; } return true; }
  var ok = true;
  var firstRow = 5, count = 14;
  // SGR press+release on row 6 (second item row)
  var sgr = Buffer.from([27, 91, 60, 48, 59, 51, 59, 54, 77, 27, 91, 60, 48, 59, 51, 59, 54, 109]);
  var r = parseInput(sgr, firstRow, count);
  ok = eq(r.clicks.length, 1, 'SGR one click') && ok;
  ok = eq(r.clicks[0], 1, 'SGR row 6 -> index 1') && ok;
  // SGR press only (no release) must not click
  var r2 = parseInput(Buffer.from([27, 91, 60, 48, 59, 51, 59, 54, 77]), firstRow, count);
  ok = eq(r2.clicks.length, 0, 'SGR press-only ignored') && ok;
  // X10/normal-mode press then release on row 6 (second item row)
  var x10 = Buffer.from([27, 91, 77, 32, 51, 38, 27, 91, 77, 35, 51, 38]);
  var r3 = parseInput(x10, firstRow, count);
  ok = eq(r3.clicks.length, 1, 'X10 one click') && ok;
  ok = eq(r3.clicks[0], 1, 'X10 row 6 -> index 1') && ok;
  // rxvt press then release
  var rx = Buffer.from([27, 91, 77, 96, 51, 38, 27, 91, 77, 99, 51, 38]);
  var r4 = parseInput(rx, firstRow, count);
  ok = eq(r4.clicks.length, 1, 'rxvt one click') && ok;
  ok = eq(r4.clicks[0], 1, 'rxvt row 6 -> index 1') && ok;
  // click above first row ignored
  var above = parseInput(Buffer.from([27, 91, 60, 48, 59, 51, 59, 52, 77, 27, 91, 60, 48, 59, 51, 59, 52, 109]), firstRow, count);
  ok = eq(above.clicks.length, 0, 'click above rows ignored') && ok;
  // click on header row 2 ignored (page 1: rows 5..18)
  var hdr = parseInput(Buffer.from([27, 91, 60, 48, 59, 51, 59, 50, 77, 27, 91, 60, 48, 59, 51, 59, 50, 109]), firstRow, count);
  ok = eq(hdr.clicks.length, 0, 'click on header ignored') && ok;
  // scroll wheel (btn 64) ignored
  var wheel = parseInput(Buffer.from([27, 91, 60, 54, 52, 59, 51, 59, 54, 77, 27, 91, 60, 54, 52, 59, 51, 59, 54, 109]), firstRow, count);
  ok = eq(wheel.clicks.length, 0, 'wheel ignored') && ok;
  // arrows, home/end
  var a = parseInput(Buffer.from([27, 91, 65]), 0, 14);
  ok = eq(a.up, true, 'CSI A up') && ok;
  var b2 = parseInput(Buffer.from([27, 91, 66]), 0, 14);
  ok = eq(b2.down, true, 'CSI B down') && ok;
  var h = parseInput(Buffer.from([27, 79, 72]), 0, 14);
  ok = eq(h.home, true, 'SS3 H home') && ok;
  var e = parseInput(Buffer.from([27, 79, 70]), 0, 14);
  ok = eq(e.end, true, 'SS3 F end') && ok;
  // digits, letters, enter, backspace, esc
  var d = parseInput(Buffer.from('10'), 0, 14);
  ok = eq(d.chars.join(''), '10', 'digits buffered') && ok;
  var l = parseInput(Buffer.from('dD'), 0, 14);
  ok = eq(l.chars.join(''), 'dD', 'letters buffered') && ok;
  var en = parseInput(Buffer.from([13]), 0, 14);
  ok = eq(en.enter, true, 'CR enter') && ok;
  var lf = parseInput(Buffer.from([10]), 0, 14);
  ok = eq(lf.enter, true, 'LF enter') && ok;
  var bs = parseInput(Buffer.from([127]), 0, 14);
  ok = eq(bs.backspace, true, 'DEL backspace') && ok;
  var es = parseInput(Buffer.from([27]), 0, 14);
  ok = eq(es.esc, true, 'lone ESC') && ok;
  // mouse + digits mixed in one chunk
  var mix = parseInput(Buffer.concat([Buffer.from([27, 91, 60, 48, 59, 51, 59, 55, 77, 27, 91, 60, 48, 59, 51, 59, 55, 109]), Buffer.from('1')]), firstRow, count);
  ok = eq(mix.clicks.length, 1, 'mix click') && ok;
  ok = eq(mix.clicks[0], 2, 'mix click index 2') && ok;
  ok = eq(mix.chars.join(''), '1', 'mix digit') && ok;
  // multi-byte UTF-8 labels survive (input side: chunk split tolerance)
  var u = parseInput(Buffer.from([27, 91, 66]), 0, 14);
  ok = eq(u.down, true, 'arrow after partial mouse buffer') && ok;
  console.log(ok ? 'PASS: font-menu parseInput/parseMouse (SGR, X10, rxvt, arrows, buffer, boundaries)' : 'FAIL: font-menu selftest');
  return ok ? 0 : 1;
}

function main() {
  if (process.argv.indexOf('--selftest') >= 0) process.exit(selftest());
  var items = parseCliItems(process.argv);
  var fi = process.argv.indexOf('--items-file');
  var title, subtitle, escapeText, escapeValue, demo = process.argv.indexOf('--demo') >= 0;
  if (fi >= 0 && fi + 1 < process.argv.length && !items) {
    try {
      var raw = require('fs').readFileSync(process.argv[fi + 1], 'utf8');
      if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1); // tolerate a PS BOM
      var payload = JSON.parse(raw);
      if (payload && Array.isArray(payload.items) && payload.items.length) {
        for (var k = 0; k < payload.items.length; k++) {
          if (!payload.items[k] || typeof payload.items[k].Key !== 'string') { payload = null; break; }
        }
      } else payload = null;
      if (payload) {
        items = payload.items;
        title = typeof payload.title === 'string' ? payload.title : undefined;
        subtitle = typeof payload.subtitle === 'string' ? payload.subtitle : undefined;
        escapeText = typeof payload.escapeText === 'string' ? payload.escapeText : undefined;
        escapeValue = typeof payload.escapeValue === 'string' ? payload.escapeValue : undefined;
      }
    } catch (e) { items = null; }
  }
  if (!items) { console.error('font-menu.cjs: pass --items \'[{"Key":"1","Label":"..."}]\''); process.exit(2); }
  var stdin = process.stdin, stdout = process.stdout;
  if (demo) { stdin.isTTY = true; stdout.isTTY = true; }
  if (!stdin.isTTY || !stdout.isTTY || typeof stdin.setRawMode !== 'function') {
    for (var i = 0; i < items.length; i++) console.log('[' + items[i].Key + '] ' + items[i].Label);
    process.exit(3);
  }
  var esc = String.fromCharCode(27);
  var prevRows = 0;
  function setRaw(m) { try { stdin.setRawMode(m); } catch (e) {} }
  title = title || 'MYANMAR FONT FIX COLLECTION';
  subtitle = subtitle || 'Up/Down: select   Enter: run   Number/letter + Enter: original mode';
  escapeText = escapeText || 'quit';
  escapeValue = escapeValue || 'Q';
  var ai = process.argv.indexOf('--title');
  if (ai >= 0 && ai + 1 < process.argv.length) title = process.argv[ai + 1];
  ai = process.argv.indexOf('--subtitle');
  if (ai >= 0 && ai + 1 < process.argv.length) subtitle = process.argv[ai + 1];
  ai = process.argv.indexOf('--escape-text');
  if (ai >= 0 && ai + 1 < process.argv.length) escapeText = process.argv[ai + 1];
  ai = process.argv.indexOf('--escape-value');
  if (ai >= 0 && ai + 1 < process.argv.length) escapeValue = process.argv[ai + 1];
  ai = process.argv.indexOf('--result-file');
  if (ai >= 0 && ai + 1 < process.argv.length) resultFile = process.argv[ai + 1];
  var pageSize = Math.max(1, stdout.rows - 6);
  var width = Math.max(1, stdout.columns - 1);
  var index = 0, buffer = '', handleESC = null, raw = Buffer.alloc(0), resultFile = null;
  var frame = buildFrame(items, index, buffer, pageSize, width, title, subtitle, escapeText);
  stdout.write(esc + '[2J' + esc + '[H'); // clear once on menu entry, then draw in place
  stdout.write(frame.join('\n') + '\n');
  prevRows = frame.length + 1; // cursor sits on row prevRows+1 below the frame top (0 extra)
  if (escapeValue !== 'Q') handleESC = function () { finish(escapeValue); };
  function redraw() {
    var f = buildFrame(items, index, buffer, pageSize, width, title, subtitle, escapeText);
    var s = esc + '[A'.repeat(prevRows); // cursor up to frame top (no scroll)
    for (var i = 0; i < f.length; i++) s += '\r' + f[i] + '\n';
    stdout.write(s);
    prevRows = f.length + 1;
  }
  function finish(value) {
    var f = buildFrame(items, index, buffer, pageSize, width, title, subtitle, escapeText);
    var s = esc + '[A'.repeat(prevRows);
    for (var i = 0; i < f.length; i++) s += '\r' + f[i] + '\n';
    s += '\r';
    stdout.write(s);
    stdout.write(esc + '[?25h' + esc + '[?1000l' + esc + '[?1006l'); // restore cursor, mouse off
    stdout.write(value + '\n');
    if (resultFile) { try { require('fs').writeFileSync(resultFile, value, 'utf8'); } catch (e) {} }
    process.exit(0);
  }
  setRaw(true);
  stdout.write(esc + '[?1000h' + esc + '[?1006h' + esc + '[?25l'); // mouse on (X10+SGR), cursor off
  stdin.on('data', function (chunk) {
    raw = Buffer.concat([raw, chunk]);
    // frame geometry: 4 header lines + blank + item rows start at line 5 => screen row of first item
    var firstScreenRow = 5;
    var acts = parseInput(raw, firstScreenRow, items.length);
    // keep an incomplete trailing mouse sequence prefix in raw; everything consumed is handled
    raw = Buffer.alloc(0); // chunks carry whole sequences; a SGR report split across reads is dropped
    if (acts.up) { index = (index + items.length - 1) % items.length; buffer = ''; redraw(); }
    if (acts.down) { index = (index + 1) % items.length; buffer = ''; redraw(); }
    if (acts.home) { index = 0; buffer = ''; redraw(); }
    if (acts.end) { index = items.length - 1; buffer = ''; redraw(); }
    if (acts.backspace && buffer.length) { buffer = buffer.slice(0, -1); redraw(); }
    if (acts.chars.length) {
      for (var ci = 0; ci < acts.chars.length; ci++) {
        var s2 = acts.chars[ci];
        if (s2.length === 1 && s2 >= '0' && s2 <= '9') buffer += s2;
        else if (s2.length === 1 && ((s2 >= 'a' && s2 <= 'z') || (s2 >= 'A' && s2 <= 'Z'))) buffer += s2.toUpperCase();
      }
      var match = -1;
      for (var mi = 0; mi < items.length; mi++) if (items[mi].Key === buffer) { match = mi; break; }
      if (match >= 0) index = match;
      redraw();
    }
    for (var ck = 0; ck < acts.clicks.length; ck++) {
      var clicked = acts.clicks[ck];
      if (clicked === index) { buffer = ''; finish(items[index].Key); return; }
      index = clicked; buffer = ''; redraw();
    }
    if (acts.esc) { if (handleESC) handleESC(); else finish('Q'); return; }
    if (acts.enter) {
      var v = null;
      if (!buffer) v = items[index].Key;
      else { for (var k = 0; k < items.length; k++) if (items[k].Key === buffer) { v = items[k].Key; break; } }
      if (v !== null) { finish(v); return; }
      redraw();
    }
  });
  var resume = function () {
    try { setRaw(true); stdout.write(esc + '[?1000h' + esc + '[?1006h'); } catch (e) {}
  };
  stdin.on('end', function () { process.exit(3); });
  process.on('SIGINT', function () { stdout.write(esc + '[?25h' + esc + '[?1000l' + esc + '[?1006l\n'); process.exit(130); });
  process.on('exit', function () { try { setRaw(false); } catch (e) {} });
  if (stdin.isPaused && stdin.isPaused()) { stdin.resume(); resume(); }
}
main();

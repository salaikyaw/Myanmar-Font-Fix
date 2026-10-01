'use strict';
// Creates a Windows .lnk shortcut file (binary, no COM/system calls needed)
// MS-SHLLINK format: ShellLinkHeader + LinkTargetIDList + LinkInfo + StringData

const fs = require('node:fs');
const path = require('node:path');

const desktop = process.env.USERPROFILE + '\\Desktop';
const lnkPath = path.join(desktop, 'MarkText (Pyidaungsu).lnk');

const targetExe = 'C:\\Windows\\System32\\wscript.exe';
const arguments_ = '"C:\\SK_AI\\projects\\Myanmar-Font-Fix\\Launch-App.vbs" marktext';
const workingDir = 'C:\\SK_AI\\projects\\Myanmar-Font-Fix';
const iconPath = 'C:\\Users\\salai\\AppData\\Local\\Programs\\marktext\\marktext.exe';
const iconIndex = 0;

function writeUtf16String(buf, offset, str) {
  const chars = Buffer.from(str, 'utf16le');
  buf.writeUInt16LE(str.length, offset);
  chars.copy(buf, offset + 2);
  return offset + 2 + chars.length;
}

// Build LinkTargetIDList for C:\Windows\System32\wscript.exe
// PIDL format for file system items: {size:uint16_le, type:byte, name:ansi_zstr, ...padding}
function buildFilesystemPidl(type, name) {
  // type: 0x1F=folder, 0x32=file
  // PIDL data: type(1) + sortindex(1) + name(ansi null-terminated) + padding to align
  const nameBuf = Buffer.from(name + '\0', 'latin1');
  const dataLen = 1 + 1 + nameBuf.length; // type + sortIndex + name
  const totalLen = 2 + dataLen; // size field + data
  const buf = Buffer.alloc(totalLen, 0);
  buf.writeUInt16LE(totalLen, 0);
  buf.writeUInt8(type, 2);
  buf.writeUInt8(0, 3); // sort index
  nameBuf.copy(buf, 4);
  return buf;
}

// Root PIDL: My Computer (CLSID {20D04FE0-3AEA-1069-A2D8-08002B30309D})
function buildRootPidl() {
  // {20D04FE0-3AEA-1069-A2D8-08002B30309D}
  const clsid = Buffer.from([0x1F, 0x00, 0xE0, 0x4F, 0xD0, 0x20, 0xEA, 0x3A, 0x69, 0xA2, 0xD8, 0x08, 0x00, 0x2B, 0x30, 0x30, 0x9D]);
  const totalLen = 2 + clsid.length;
  const buf = Buffer.alloc(totalLen, 0);
  buf.writeUInt16LE(totalLen, 0);
  clsid.copy(buf, 2);
  return buf;
}

// Drive PIDL for C:
function buildDrivePidl() {
  // Drive PIDL: 0x1F, 0x00, 0x00, 0x43, 0x3A (C:) + padding
  const data = Buffer.from([0x1F, 0x00, 0x00, 0x43, 0x3A]);
  const totalLen = 2 + data.length + 12; // pad to make it look right
  const buf = Buffer.alloc(totalLen, 0);
  buf.writeUInt16LE(totalLen, 0);
  data.copy(buf, 2);
  return buf;
}

// Build the complete LinkTargetIDList
function buildLinkTargetIDList() {
  const root = buildRootPidl();
  const drive = buildDrivePidl();
  const winDir = buildFilesystemPidl(0x1F, 'Windows');
  const sysDir = buildFilesystemPidl(0x1F, 'System32');
  const file = buildFilesystemPidl(0x32, 'wscript.exe');
  const terminal = Buffer.alloc(2, 0); // 0x0000 terminal

  const idList = Buffer.concat([root, drive, winDir, sysDir, file, terminal]);
  const sizeField = Buffer.alloc(2, 0);
  sizeField.writeUInt16LE(idList.length, 0);
  return Buffer.concat([sizeField, idList]);
}

// Build LinkInfo with LocalBasePath
function buildLinkInfo() {
  const localBasePath = targetExe; // "C:\Windows\System32\wscript.exe"
  const basePathBuf = Buffer.from(localBasePath + '\0', 'latin1');

  // VolumeID structure (fixed 16 bytes for basic)
  // VolumeIDSize: uint32_le = 16
  // DriveLetter: uint32_le (0x43 = 'C')
  // DriveSerialNumber: uint32_le = 0
  // VolumeLabelOffset: uint32_le = 16 (end of VolumeID, no label)
  // VolumeLabelOffsetUnicode: uint32_le = 0 (not used)
  const volumeID = Buffer.alloc(16, 0);
  volumeID.writeUInt32LE(16, 0);     // VolumeIDSize
  volumeID.writeUInt32LE(0x0043, 4); // DriveLetter 'C'
  volumeID.writeUInt32LE(0, 8);      // DriveSerialNumber
  volumeID.writeUInt32LE(16, 12);    // VolumeLabelOffset (points to end = no label)

  // LinkInfo structure:
  // LinkInfoSize: uint32_le
  // LinkInfoHeaderSize: uint32_le = 0x1C (28)
  // LinkInfoFlags: uint32_le = 0x01 (VolumeIDAndLocalBasePath)
  // VolumeIDOffset: uint32_le (offset from start of LinkInfo to VolumeID)
  // LocalBasePathOffset: uint32_le (offset from start of LinkInfo to LocalBasePath)
  // CommonNetworkRelativeLinkOffset: uint32_le = 0
  // CommonPathSuffixOffset: uint32_le = 0

  const headerSize = 28;
  const volumeIDOffset = headerSize;
  const localBasePathOffset = volumeIDOffset + volumeID.length;
  const totalSize = localBasePathOffset + basePathBuf.length;

  const linkInfo = Buffer.alloc(totalSize, 0);
  linkInfo.writeUInt32LE(totalSize, 0);
  linkInfo.writeUInt32LE(headerSize, 4);
  linkInfo.writeUInt32LE(0x01, 8);           // VolumeIDAndLocalBasePath
  linkInfo.writeUInt32LE(volumeIDOffset, 12);
  linkInfo.writeUInt32LE(localBasePathOffset, 16);
  linkInfo.writeUInt32LE(0, 20);             // CommonNetworkRelativeLinkOffset
  linkInfo.writeUInt32LE(totalSize, 24);     // CommonPathSuffixOffset (points to end)

  volumeID.copy(linkInfo, volumeIDOffset);
  basePathBuf.copy(linkInfo, localBasePathOffset);

  return linkInfo;
}

// Build the complete .lnk file
function buildLnk() {
  const parts = [];

  // --- ShellLinkHeader (76 bytes) ---
  const header = Buffer.alloc(76, 0);
  let o = 0;
  header.writeUInt32LE(0x4C, o); o += 4; // HeaderSize
  // CLSID {00021401-0000-0000-C000-000000000046}
  const clsid = [0x01,0x14,0x02,0x00,0x00,0x00,0x00,0x00,0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46];
  for (let i = 0; i < 16; i++) header[o + i] = clsid[i];
  o += 16;
  // Flags: HasLinkTargetIDList(0x01) | HasLinkInfo(0x02) | HasWorkingDir(0x10) | HasArguments(0x20) | HasIconLocation(0x40) = 0x73
  header.writeUInt32LE(0x73, o); o += 4;
  header.writeUInt32LE(0, o); o += 4; // FileAttributes
  header.writeBigUInt64LE(0n, o); o += 8; // CreationTime
  header.writeBigUInt64LE(0n, o); o += 8; // AccessTime
  header.writeBigUInt64LE(0n, o); o += 8; // WriteTime
  header.writeUInt32LE(0, o); o += 4; // FileSize
  header.writeInt32LE(iconIndex, o); o += 4; // IconIndex
  header.writeUInt32LE(1, o); o += 4; // ShowCommand = SW_SHOWNORMAL
  header.writeUInt16LE(0, o); o += 2; // HotKey
  header.writeUInt16LE(0, o); o += 2; // Reserved1
  header.writeUInt32LE(0, o); o += 4; // Reserved2
  header.writeUInt32LE(0, o); o += 4; // Reserved3
  parts.push(header);

  // --- LinkTargetIDList ---
  parts.push(buildLinkTargetIDList());

  // --- LinkInfo ---
  parts.push(buildLinkInfo());

  // --- StringData ---
  // Order: WORKING_DIR, COMMAND_LINE_ARGUMENTS, ICON_LOCATION
  // Need a buffer large enough; let's build dynamically
  const strParts = [];

  // WORKING_DIR
  const wdBuf = Buffer.alloc(2 + Buffer.from(workingDir, 'utf16le').length);
  writeUtf16String(wdBuf, 0, workingDir);
  strParts.push(wdBuf);

  // COMMAND_LINE_ARGUMENTS
  const argBuf = Buffer.alloc(2 + Buffer.from(arguments_, 'utf16le').length);
  writeUtf16String(argBuf, 0, arguments_);
  strParts.push(argBuf);

  // ICON_LOCATION
  const iconBuf = Buffer.alloc(2 + Buffer.from(iconPath, 'utf16le').length);
  writeUtf16String(iconBuf, 0, iconPath);
  strParts.push(iconBuf);

  parts.push(Buffer.concat(strParts));

  // --- ExtraData: EnvironmentVariableDataBlock (optional but helps) ---
  // Actually, let's add a terminal block (0x00000000)
  parts.push(Buffer.alloc(4, 0));

  return Buffer.concat(parts);
}

const lnkData = buildLnk();
fs.writeFileSync(lnkPath, lnkData);
console.log(`SUCCESS: Shortcut created at ${lnkPath} (${lnkData.length} bytes)`);

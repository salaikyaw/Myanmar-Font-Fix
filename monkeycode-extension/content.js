/*
 * MonkeyCode Pyidaungsu renderer patch.
 *
 * Deliberately CSS-only: rewriting chat DOM text or editor input is unsafe.
 */
(() => {
  const marker = 'sk-pyidaungsu-monkeycode-font-v2';

  function injectStyles() {
    if (document.getElementById(marker)) return;
    const style = document.createElement('style');
    style.id = marker;
    style.textContent = `
      html, body,
      input, textarea, button, select,
      [contenteditable="true"], [role="textbox"],
      [class*="message"], [class*="chat"], [class*="content"] {
        font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important;
        font-variant-ligatures: normal !important;
      }

      pre, code, kbd, samp, .xterm, .monaco-editor,
      .monaco-editor textarea, .monaco-editor input {
        font-family: "Cascadia Mono", "JetBrains Mono", Consolas, monospace !important;
      }
    `;
    (document.head || document.documentElement).appendChild(style);
  }

  injectStyles();
  document.addEventListener('DOMContentLoaded', injectStyles, { once: true });
})();

(() => {
  const marker = 'sk-pyidaungsu-font-fix';
  const install = () => {
    if (document.getElementById(marker)) return;
    const style = document.createElement('style');
    style.id = marker;
    style.textContent = `
      html, body, body *:not(pre):not(code):not(kbd):not(samp),
      input, textarea, button, [contenteditable="true"], [role="textbox"] {
        font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
      }
      pre, code, kbd, samp {
        font-family: "Cascadia Mono", Consolas, monospace !important;
      }
    `;
    (document.head || document.documentElement).appendChild(style);
  };
  install();
  document.addEventListener('DOMContentLoaded', install, { once: true });
})();

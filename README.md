# Myanmar Font Fix Collection

![Myanmar Font Fix banner](docs/assets/myanmar-font-fix-banner.png)

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows)](https://github.com/salaikyaw/Myanmar-Font-Fix)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell)](https://github.com/salaikyaw/Myanmar-Font-Fix)
[![License: MIT](https://img.shields.io/badge/License-MIT-gold.svg)](LICENSE)

[မြန်မာဘာသာဖြင့် ဖတ်ရန်](README.my.md)

Windows app-local Pyidaungsu launchers, UTF-8 terminal profiles, and the existing local repair collection.

## Quick start

1. Install Pyidaungsu from a trusted source. Font files are **not redistributed** here.
2. Install Node.js 22+ and use Windows PowerShell 5.1+.
3. Clone this repository and run `npm install`.
4. Run `Run-Repair-Font.bat`, choose **I** to create/update desktop shortcuts.
5. Save your work and completely exit the selected app, including its tray icon.
6. Open the app using its **(Pyidaungsu)** shortcut. Subsequent launches use the current installed executable. Factory's versioned installation is rediscovered each time.
7. Choose **S** for the last renderer verification. `READY` means installed, **not** visually verified. A successful CSS/font probe does not prove every conversation, embedded frame, canvas, or terminal surface renders correctly.

New app entries: Freebuff, AutoClaw, Genspark Claw (not Genspark Browser), Factory, Hermes Desktop (not the setup app), LM Studio, OpenWorker, AnythingLLM, Kimi, Qoder, MDHero.

Kimi's main chat is hosted at `https://www.kimi.com`; only that exact origin is allowlisted for its app-owned debugging port. Its auxiliary local windows are excluded. The launcher never navigates to or reads browser profiles.

## Why launchers?

New launchers do not unpack/rewrite signed vendor archives, restore stale binaries, change chats/models, disable TLS, or kill running apps. They inject font CSS into the app's local page via a loopback-only debugging endpoint. CSS is reinstalled after reload/navigation. Hidden helpers check every three seconds and exit after the renderer is unavailable for sixty seconds. No scheduled task or boot service is installed.

Use the Pyidaungsu shortcut after updates; ordinary vendor shortcuts bypass runtime injection. Runtime updates can still remove debugging support, change the renderer origin, or change installation paths. In that case the launcher must fail rather than claim success. See `apps.json` for locally verified installation paths.

**Security:** a local debugging port grants control of the app to other processes running on this PC. Configured ports 19431–19441 and automatic conflict-fallback ports 19500–19599 must stay loopback-only; never port-forward or expose them. A repeated shortcut launch reuses a fallback port only after proving that the exact app executable owns it. Orphaned or foreign listeners are never attached. Only use these launchers on a trusted local machine. WebView2 launchers additionally set an **executable-only** HKCU policy, with a backup. This is not a wildcard or system-wide policy; however, ordinary launches of that executable also inherit the policy until restored. Remote login/web pages are deliberately excluded from CSS injection.

## CMD / PowerShell / Codex CLI

Menu **T** installs separate `PowerShell (Myanmar)` and `CMD (Myanmar)` Windows Terminal profiles and shortcuts. Existing Terminal settings/default profile, shell profiles, and system locale are untouched. Run `codex` or another CLI inside those profiles. UTF-8 and font selection solve different problems. Pyidaungsu is proportional; terminal cell widths, cursor handling, and individual TUI implementations can still render complex Myanmar text imperfectly. Do not interpret profile installation as an end-to-end CLI rendering test.

Microsoft references: [JSON fragment extensions](https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions), [font appearance settings](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance).

## Layout and local operation

- The project can be cloned to any writable local folder.
- Entry point: `Run-Repair-Font.bat`
- Local status/backups: `%LOCALAPPDATA%\Myanmar-Font-Fix`
- **L** opens the existing collection under `legacy/`. Its older app-specific repairs are retained for continuity, not silently run as part of new-app setup.
- Original collection remains untouched as a rollback source. Its unrelated network/disk scripts and private recovered chats are not part of this project.

There is no need to put another copy of the project under `scripts`; one launcher points to this canonical copy.

## Rollback

For new app repairs: completely exit the app, then open its original vendor shortcut. No vendor files need restoring. For a WebView2 app, restore its executable-specific policy from `%LOCALAPPDATA%\Myanmar-Font-Fix\<app>-webview-policy-original.json` before reopening if full rollback is required. Remove only the generated Pyidaungsu shortcuts if no longer wanted. For terminal profiles: remove the dedicated `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\Myanmar-Font-Fix\profiles.json`, then restart Terminal. Existing shortcut backups are stored in the local backup folder. Legacy repairs have their own backup/restore behavior; read the specific script before use.

## Privacy and redistribution

Runtime data, backups, local status reports, vendor dependencies and font binaries are excluded. Pyidaungsu is not redistributed by this repository. Review the warning shown by each legacy repair before running it: some legacy actions close applications, patch installed resources or require administrator rights. App updates can invalidate those patches.
# Keyboard menu navigation

The collection menu supports both input styles:

- Arrow keys plus Enter, with a high-contrast yellow selection bar.
- The original number or letter plus Enter shortcuts.
- Escape goes back inside Legacy/Manual menus and quits from the main menu.
- Actions return to their current menu; `Q` exits the collection.
- Legacy Manual Selection includes individual repairs, `A` for all installed applications, and `M` for comma-separated multi-selection.

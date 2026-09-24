# Contributing

Bug reports and app-path updates are welcome. Please include the application name and version, Windows version, the exact menu action used, and whether the problem affects display, typing, or both. Never attach account data, chat history, tokens, cookies, or complete application profiles.

Before opening a pull request:

1. Keep paths portable by using environment variables and `$PSScriptRoot`.
2. Do not bundle font binaries, vendor application files, backups, or user data.
3. Run `npm install` and then `npm test` from Windows PowerShell.
4. Explain whether the result was configuration-tested or visually verified in the live application.

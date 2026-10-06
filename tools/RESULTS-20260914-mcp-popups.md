# 2026-09-14 MCP, console popups, and Chrome investigation

## Verified from Windows after final gateway restarts

Command: `python myanmar-font-fix/tools/probe-dell-mcp.py 192.168.1.4 --call`

| Gateway | Tools | Read-only functional test |
|---|---:|---|
| core | 19 | fetch example.com passed |
| coding | 29 | Context7 resolve-library-id passed |
| automation | 88 | discovery only |
| collaboration | 24 | discovery only |
| data | 6 | discovery only |
| research | 2 | Context7 resolve-library-id passed |
| cloud | 4 | Cloudflare documentation search passed |
| system | 11 | list_allowed_directories passed |
| trading | 43 | discovery only; no orders placed |
| searx | 4 | discovery only |

All ten systemd units active. Discovery is not proof of every tool's credentials or functionality. Existing Requires chains stop downstream gateways when an upstream gateway restarts; start all downstream units again and rerun the consumer probe.

## Network changes and dependency

Dell direct public DNS/HTTPS failed, while sk-hp egress worked. Dell now uses an SSH SOCKS tunnel to sk-hp on loopback 1082, a TLS-transparent HTTP CONNECT proxy on loopback and docker0 port 1083, and a loopback DNS relay on 5354. Services: mcp-egress-skhp, mcp-http-egress, mcp-dns-egress. Docker0 firewall rule is restricted to 172.17.0.0/16 -> 172.17.0.1 TCP 1083. No global route change or TLS/signature bypass.

IMPORTANT: sk-hp must remain reachable/awake for these internet-facing tools AND Dell's current public DNS resolution. `/etc/systemd/resolved.conf.d/95-mcp-dns.conf` routes public DNS through the relay. This is a recovery dependency, not an independent internet fix.

Official local catalog: `/home/sk-dell-1/.docker/mcp/catalogs/docker-official-20260914.yaml`. Image-based MCPs receive proxy environment entries. Context7 and Cloudflare docs use the locally built `mcp-remote-egress:local` adapter (source and Dockerfile in this directory and `/home/sk-dell-1/mcp-host/egress-adapter`). Cloudflare legacy SSE returned HTTP 410; replaced with Streamable HTTP at https://docs.mcp.cloudflare.com/mcp. Context7 remains https://mcp.context7.com/mcp. Research currently uses the separately authenticated native relay via `92-context7-relay.conf`.

Backups on Dell:
- `/var/backups/mcp-catalog-20260914-18M5z0`
- `/var/backups/mcp-catalog-20260914-GbCnAb`
- `/var/backups/mcp-egress-20260914-V9kD2Z`
- `/var/backups/mcp-http-20260914-12xzdoqr`
- `/var/backups/mcp-adapters-20260914-v_cl6g_b` (catalog immediately before adapter conversion)

Rollback must coordinate catalog, unit drop-ins, relay services, DNS drop-in, and the single firewall rule. Do not stop the relay before restoring a working DNS/egress path. Old installation scripts are diagnostic migration steps, NOT a universal idempotent repair installer.

## Windows console popups

PowerManager and SSH-Sync-to-GDrive actions now use fixed-path WScript hidden launchers. Triggers and task settings preserved. Original task XMLs: `C:\SK_AI\backups\hidden-tasks-20260914`. PowerManager relaunched once with the wrapper. SSH sync subsequently completed with LastTaskResult 0. The sync script itself was not changed or manually invoked. Verdent/DC stable activity windows and unrelated user terminals were preserved. No claim that every intermittent popup is identified.

Battery observed on AC, not charging/discharging, at approximately 87%. Firmware-reported full/design capacity both 33510 mWh is insufficient evidence to quantify wear. The reviewed battery manager does not set a charging cap. No forced discharge, firmware setting, or calibration performed.

## Dell fan/CPU

Identified runaway landscape-sysinfo PID 3230095 using about one full CPU for ~6.6 hours. Terminated that exact process. Archived the MOTD link under `/var/backups/landscape-20260914`; renamed `/etc/update-motd.d/50-landscape-sysinfo` to `50-landscape-sysinfo.disabled` to prevent automatic login execution. The process disappeared. Important services were not disabled.

## Chrome remains unresolved

User reports intermittent new windows during Myanmar typing / Ctrl+Shift, and suspects correlation with Codex being open. It does NOT happen on every Ctrl+Shift press.

Observed browser root launched by Explorer, plain chrome.exe command without URL, title New Tab. Parent alone does not identify the program requesting a shell launch. No agent browser-opening tool was used during this investigation. Five legacy browser-control MCP entries are already disabled. Other browser integrations remain enabled.

Chrome Profile 26 has extension `ChatGPT` version 1.26.901.11451, ID hehggadaopoacecdllhhajmbjkdcmajg. Chrome launches its Codex native messaging host; this is not proof that Codex launches the new windows. Codex logs show browser integration setup and Appshot DoubleAlt registration failure, but no confirmed matching Chrome-launch event. KeyMagic's config remains untouched. No extension, keyboard, or browser integration was disabled based on speculation.

Next discriminating test: temporarily disable only the ChatGPT Chrome extension via chrome://extensions, leaving Codex open, then reproduce normal Myanmar typing. Re-enable afterward and compare. No persistent key logging or background diagnostic monitor was installed.

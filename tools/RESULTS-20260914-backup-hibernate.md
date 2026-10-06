# Backup and hibernate test results — 2026-09-14

## localserver-1 backup
- Verified encrypted archive on sk-hp HDD: `/mnt/sk-hp-data/localserver-1-backup-20260914-NxvZww/rootfs.tar.zst.gpg` (9.8 GiB displayed by du).
- Full decryption/decompression/tar listing succeeded: 512,653 entries. SHA256SUMS and VERIFIED_ARCHIVE status written.
- File-level live-system archive, not a disk image. See BACKUP-RECOVERY-20260914.md for exclusions and recovery key locations. No restoration into a new machine has been tested.
- Source tar returned success. Some mounted Snap filesystem xattr warnings occurred. Kernel SATA errors still occurred during copying; archive success does not certify source hardware or pre-existing file contents.
- No disk format, badblocks write test, mounted-root fsck or swap-file deletion performed.

## sk-hp actual hibernate test
- 08:23:05 +0630: kernel hibernation entry.
- 08:25:27 +0630: kernel hibernation exit, same boot ID comparison passed.
- RTC alarm was armed for approximately 08:25:05; user was requested not to touch controls. User confirmation of no manual input is pending.
- Runtime resume offset 4093952 persisted.
- Built-in keyboard bind_mode manual, atkbd unbound both immediately and minutes after resume.
- All pre-test running services remained active, excluding the test service itself which completed successfully.
- Battery monitor active; Ollama HTTP 200; port 4000 listening.
- Both data HDD mounts available; verified backup status still readable after resume.
- RTC wake is not proof of wake solely on mains restoration or Wake-on-LAN.

## Dell service restoration and remaining blockers
- Docker, containerd, battery-monitor and SearX gateway active; SearX HTTP 200.
- Core/coding/automation/collaboration MCP gateways failed to restart because external Docker catalog and Docker Hub verification connections timed out.
- Official catalog fetched through sk-hp and copied into Dell's ~/.docker/mcp/catalogs/docker-official-20260914.yaml.
- Reversible 90-local-catalog.conf drop-ins added for these four units; original merged unit backups: /var/backups/mcp-catalog-20260914-18M5z0.
- Catalog read now succeeds, but Docker image verification still times out. Signature verification was NOT disabled. MCP availability is not restored yet.
- Dell real hibernate test deferred due recurring SATA bus/read I/O errors. More swap cannot fix this storage-path fault.

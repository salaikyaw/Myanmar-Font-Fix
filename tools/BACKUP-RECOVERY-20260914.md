# localserver-1 backup (2026-09-14)

Destination on sk-hp: `/mnt/sk-hp-data/localserver-1-backup-20260914-NxvZww/`

This is an encrypted Linux file archive, not a sector image or automatically bootable clone.
Only `STATUS` containing `VERIFIED_ARCHIVE` denotes completed archive validation.
Do not treat a `.partial` file as a completed backup.

Recovery passphrase files (never print or share their contents):
- sk-hp: `/home/sk-hp/.localserver-1-recovery-20260914-lCBQjt/passphrase`
- Windows: `C:\Users\salai\.codex\recovery\localserver-1-20260914\passphrase`

The source pipeline stops active MCP gateway, Docker and containerd units and requests
their restart on exit. This is a file-level backup of a live OS, not an atomic snapshot.
It preserves tar numeric ownership, ACLs, xattrs and sparse-file layout. Root filesystem
and EFI directory are included. Swap files, virtual filesystems, mount trees, temporary
files, logs and cache are excluded. Existing swap files are not deleted.

Archive validation decrypts the entire archive and parses all tar entries; a SHA256
checksum is also generated. This verifies archive readability, not a bare-metal restore.
An interrupted transfer or source read error must be resolved before using it as a
complete recovery copy. Never overwrite a running root filesystem to test restoration.

To inspect on Linux (replace paths with verified absolute paths):

```sh
gpg --batch --pinentry-mode loopback --passphrase-file /path/to/passphrase \
  --decrypt /path/to/rootfs.tar.zst.gpg | zstd -d | tar -tf -
```

Extract only to a new empty recovery directory on a healthy Linux filesystem.
Filesystem formatting, bootloader installation and swap regeneration are separate
recovery steps requiring a verified target device.

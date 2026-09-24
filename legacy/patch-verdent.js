/*
 * Verdent 2.12.3 enables Electron ASAR integrity checking. Mutating app.asar
 * makes the signed application exit before its logger starts. Keep this
 * guard as the repair entry point so future runs restore the vendor bundle
 * instead of corrupting it again. Font injection must use a launch-time
 * mechanism outside app.asar.
 */
const fs = require('fs');
const crypto = require('crypto');

const asarPath = 'C:\\Program Files\\Verdent\\resources\\app.asar';
const backupPath = `${asarPath}.pyidaungsu-bak`;

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

if (!fs.existsSync(asarPath) || !fs.existsSync(backupPath)) {
  console.error('VERDENT_RESTORE_FAILED: app.asar or vendor backup is missing');
  process.exit(1);
}

const currentHash = sha256(asarPath);
const vendorHash = sha256(backupPath);
if (currentHash === vendorHash) {
  console.log('VERDENT_VENDOR_ASAR_OK');
  process.exit(0);
}

const damagedCopy = `${asarPath}.rejected-${new Date().toISOString().replace(/[:.]/g, '-')}`;
fs.copyFileSync(asarPath, damagedCopy);
fs.copyFileSync(backupPath, asarPath);

if (sha256(asarPath) !== vendorHash) {
  console.error('VERDENT_RESTORE_FAILED: post-copy hash mismatch');
  process.exit(1);
}

console.log(`VERDENT_VENDOR_ASAR_RESTORED backup=${damagedCopy}`);

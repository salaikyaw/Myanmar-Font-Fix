[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSCommandPath
$sidecar = Join-Path $root 'Start-AntigravityHiddifySidecar.ps1'

while ($true) {
    try {
        & $sidecar -WaitForReady | Out-Null
    } catch {
        # Do not surface or record profile credentials.  The next pass retries
        # only the local listener/startup check.
    }
    Start-Sleep -Seconds 20
}

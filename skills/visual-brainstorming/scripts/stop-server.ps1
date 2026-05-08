# Stop the Edan Visual Brainstorming server and clean up
# Usage: .\stop-server.ps1 <session_dir>
#
# Kills the server process. Only deletes session directory if it's
# under temp (ephemeral). Persistent directories (.edan-dev/) are
# kept so mockups can be reviewed later.

param(
    [Parameter(Mandatory=$true)]
    [string]$SessionDir
)

$stateDir = Join-Path $SessionDir "state"
$pidFile = Join-Path $stateDir "server.pid"

if (-not (Test-Path $pidFile)) {
    Write-Output '{"status": "not_running"}'
    exit 0
}

$pidValue = Get-Content $pidFile -Raw

try {
    # Try graceful shutdown first
    Stop-Process -Id $pidValue -Force -ErrorAction Stop

    # Wait up to 2 seconds
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 100
        try {
            $null = Get-Process -Id $pidValue -ErrorAction Stop
        } catch {
            break
        }
    }

    # If still running, it's already been force-killed by Stop-Process -Force
    # Just verify
    try {
        $null = Get-Process -Id $pidValue -ErrorAction Stop
        Write-Output '{"status": "failed", "error": "process still running"}'
        exit 1
    } catch {
        # Process is dead, continue cleanup
    }

    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $stateDir "server.log") -Force -ErrorAction SilentlyContinue

    # Only delete ephemeral temp directories
    $tempPaths = @($env:TEMP, "/tmp", "C:\temp")
    $isTemp = $false
    foreach ($tp in $tempPaths) {
        if ($tp -and $SessionDir.StartsWith($tp)) {
            $isTemp = $true
            break
        }
    }

    if ($isTemp) {
        Remove-Item $SessionDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Output '{"status": "stopped"}'
} catch {
    Write-Output "{`"status`": `"error`", `"message`": `"$($_.Exception.Message)`"}"
    exit 1
}

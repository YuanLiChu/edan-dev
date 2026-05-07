# Start the Edan Visual Brainstorming server and output connection info
# Usage: .\start-server.ps1 [-ProjectDir <path>] [-Host <bind-host>] [-UrlHost <display-host>] [-Foreground]
#
# Starts server on a random high port, outputs JSON with URL.
# Each session gets its own directory to avoid conflicts.
#
# Options:
#   -ProjectDir <path>  Store session files under <path>/.edan-dev/brainstorm/
#                       instead of temp. Files persist after server stops.
#   -Host <bind-host>   Host/interface to bind (default: 127.0.0.1).
#   -UrlHost <host>     Hostname shown in returned URL JSON.
#   -Foreground         Run server in the current terminal (no backgrounding).

param(
    [string]$ProjectDir = "",
    [string]$Host = "127.0.0.1",
    [string]$UrlHost = "",
    [switch]$Foreground
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

if ([string]::IsNullOrEmpty($UrlHost)) {
    if ($Host -eq "127.0.0.1" -or $Host -eq "localhost") {
        $UrlHost = "localhost"
    } else {
        $UrlHost = $Host
    }
}

# Windows PowerShell auto-foreground
$isWindowsEnv = $env:OS -eq "Windows_NT" -or $env:MSYSTEM -or $PSVersionTable.Platform -eq "Win32NT"
if ($isWindowsEnv -and -not $Foreground) {
    Write-Host "Windows detected: running in foreground mode. Use run_in_background=true if calling via AI tool."
    $Foreground = $true
}

# Generate unique session directory
$sessionId = "$PID-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"

if ($ProjectDir) {
    $sessionDir = Join-Path $ProjectDir ".edan-dev/brainstorm/$sessionId"
} else {
    $tempBase = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
    $sessionDir = Join-Path $tempBase "edan-brainstorm-$sessionId"
}

$stateDir = Join-Path $sessionDir "state"
$pidFile = Join-Path $stateDir "server.pid"
$logFile = Join-Path $stateDir "server.log"

# Create directories
New-Item -ItemType Directory -Path (Join-Path $sessionDir "content") -Force | Out-Null
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

# Kill any existing server
if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -Raw
    try {
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
    } catch {}
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

# Owner PID: parent process of this script
$ownerPid = $PID

# Environment setup
$env:EDAN_VB_DIR = $sessionDir
$env:EDAN_VB_HOST = $Host
$env:EDAN_VB_URL_HOST = $UrlHost
$env:EDAN_VB_OWNER_PID = $ownerPid

if ($Foreground) {
    $PID | Set-Content $pidFile
    & node (Join-Path $scriptDir "server.cjs")
    exit $LASTEXITCODE
}

# Background mode (not typically used on Windows)
$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodePath) {
    Write-Output '{"error": "Node.js not found in PATH"}'
    exit 1
}

$proc = Start-Process -FilePath $nodePath -ArgumentList (Join-Path $scriptDir "server.cjs") `
    -RedirectStandardOutput $logFile -RedirectStandardError $logFile `
    -WindowStyle Hidden -PassThru

$proc.Id | Set-Content $pidFile

# Wait for server-started message (check log file)
$started = $false
for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Milliseconds 100
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        if ($logContent -and $logContent.Contains("server-started")) {
            # Verify process is still alive
            try {
                $null = Get-Process -Id $proc.Id -ErrorAction Stop
                $started = $true
                break
            } catch {
                Write-Output "{`"error`": `"Server started but was killed. Retry with -Foreground.`"}"
                exit 1
            }
        }
    }
}

if (-not $started) {
    Write-Output '{"error": "Server failed to start within 5 seconds"}'
    exit 1
}

# Output the server-started line
$logContent = Get-Content $logFile -Raw
$startedLine = ($logContent -split "`n") | Where-Object { $_ -match "server-started" } | Select-Object -First 1
Write-Output $startedLine

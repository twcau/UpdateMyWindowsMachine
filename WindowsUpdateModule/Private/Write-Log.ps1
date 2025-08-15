    $showDebug = $true
    if ($Level -eq "DEBUG" -and -not $script:DebugMode) { $showDebug = $false }
    if ($showDebug) {
        switch ($Level) {
            "HEADER" { Write-Host $screenEntry -ForegroundColor Cyan; [System.Console]::ResetColor() }
            "SUCCESS" { Write-Host $screenEntry -ForegroundColor Green; [System.Console]::ResetColor() }
            "ERROR" { Write-Host $screenEntry -ForegroundColor Red; [System.Console]::ResetColor() }
            "WARN" { Write-Host $screenEntry -ForegroundColor Yellow; [System.Console]::ResetColor() }
            "NOTIFY" { Write-Host $screenEntry -ForegroundColor Magenta; [System.Console]::ResetColor() }
            "ASK" { Write-Host $screenEntry -ForegroundColor White; [System.Console]::ResetColor() }
            default { Write-Host $screenEntry }
        }
        if ($PostBreak) { Write-Host "" }
    }
    if ($showDebug) {
        try {
            if (-not $SuppressLogFile -and $logFile -and (Test-Path (Split-Path $logFile -Parent))) {
                # Log rotation: if log file > 5MB, archive and start new
                if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 5MB)) {
                    $archiveDir = Join-Path (Split-Path $logFile -Parent) 'Archive'
                    if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }
                    $archiveName = "log_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".txt"
                    Move-Item $logFile (Join-Path $archiveDir $archiveName)
                }
                Add-Content -Path $logFile -Value $logEntry
            }
            elseif (-not $SuppressLogFile) {
                Write-Host "[LOGGING WARNING] Could not write to log file: $logFile" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[LOGGING ERROR] Failed to write to log file: $logFile" -ForegroundColor Red
        }
    }
function Write-Log {
    <#
    .SYNOPSIS
        Logs a message to the screen and log file, with color and level.
    .DESCRIPTION
        Handles log rotation and size limits. Supports colorized output and log file suppression.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        The log level (INFO, HEADER, NOTIFY, SUCCESS, WARN, ERROR, ASK).
    .PARAMETER PreBreak
        If set, adds a blank line before the message.
    .PARAMETER PostBreak
        If set, adds a blank line after the message.
    .PARAMETER ShowTimestampOnScreen
        If set, shows timestamp in terminal output.
    .PARAMETER SuppressLogFile
        If set, does not write to the log file.
    #>
    [CmdletBinding()]
    param (
        [string]$Message,
        [ValidateSet("INFO", "HEADER", "NOTIFY", "SUCCESS", "WARN", "ERROR", "ASK")]
        [string]$Level = "INFO",
        [switch]$PreBreak,
        [switch]$PostBreak,
        [switch]$ShowTimestampOnScreen = $false,
        [switch]$SuppressLogFile
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    $screenEntry = ""
    if ($ShowTimestampOnScreen) { $screenEntry += "[$timestamp]" }
    if ($script:ShowLevelOnScreen) { $screenEntry += "[$Level] " }
    $screenEntry += $Message

    ## Terminal output with optional line breaks and color
    if ($PreBreak) { Write-Host "" }
    switch ($Level) {
        "HEADER" {
            [System.Console]::ResetColor()
            Write-Host $screenEntry -ForegroundColor White -BackgroundColor Blue
            [System.Console]::ResetColor()
            Write-Host ""
        }
        "NOTIFY" {
            Write-Host $screenEntry -ForegroundColor Yellow
            [System.Console]::ResetColor()
        }
        "SUCCESS" {
            Write-Host $screenEntry -ForegroundColor Green
            [System.Console]::ResetColor()
        }
        "WARN" {
            Write-Host $screenEntry -ForegroundColor Yellow -BackgroundColor Black
            [System.Console]::ResetColor()
        }
        "ERROR" {
            Write-Host $screenEntry -ForegroundColor Red
            [System.Console]::ResetColor()
        }
        "ASK" {
            Write-Host $screenEntry -ForegroundColor White
            [System.Console]::ResetColor()
        }
        default { Write-Host $screenEntry }
    }
    if ($PostBreak) { Write-Host "" }
    try {
        if (-not $SuppressLogFile -and $logFile -and (Test-Path (Split-Path $logFile -Parent))) {
            # Log rotation: if log file > 5MB, archive and start new
            if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 5MB)) {
                $archiveDir = Join-Path (Split-Path $logFile -Parent) 'Archive'
                if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }
                $archiveName = "log_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".txt"
                Move-Item $logFile (Join-Path $archiveDir $archiveName)
            }
            Add-Content -Path $logFile -Value $logEntry
        }
        elseif (-not $SuppressLogFile) {
            Write-Host "[LOGGING WARNING] Could not write to log file: $logFile" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[LOGGING ERROR] Failed to write to log file: $logFile" -ForegroundColor Red
    }
}

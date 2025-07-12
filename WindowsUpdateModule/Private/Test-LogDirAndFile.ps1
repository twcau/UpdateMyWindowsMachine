function Test-LogDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogDir,
        [Parameter()]
        [string]$ScriptDir
    )
    $ErrorActionPreference = 'Stop'
    $logDir = $LogDir.Trim()
    if ([string]::IsNullOrWhiteSpace($logDir)) {
        $logDir = Join-Path $ScriptDir 'Logs'
    }
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        } catch {
            $logDir = Join-Path $env:TEMP 'WindowsUpdateLogs'
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
        }
    }
    $logDir
}

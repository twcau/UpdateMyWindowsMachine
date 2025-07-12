function Set-GlobalsFromConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    # Defensive: Use correct case for config keys
    $defaultLogDir = Join-Path $PSScriptRoot 'Logs'
    $logDirRaw = $Config.LogDir
    if ([string]::IsNullOrWhiteSpace($logDirRaw)) {
        $logDirRaw = $defaultLogDir
    }
    $script:LogDir = Test-LogDirectory $logDirRaw
    $script:DaysToKeep = $Config.DaysToKeep
    $script:TimeoutSeconds = $Config.TimeoutSeconds
    $script:UpdateTypes = $Config.UpdateTypes
    $script:ShowTimestampOnScreenentry = $Config.ShowTimestampOnScreenentry
    $script:ShowLevelOnScreen = $Config.ShowLevelOnScreen
    $script:ArchiveRetentionDays = $Config.ArchiveRetentionDays
    $script:WingetSkipList = $Config.wingetSkipList
    $script:ScheduledTask = $Config.ScheduledTask
    # Log file naming with date and time
    $script:LogFile = Join-Path $script:LogDir ("UpdateScript-" + (Get-Date -Format 'yyyyMMdd_HHmm') + ".log")
    $script:LogFileMicrosoftStore = (Get-Date -Format 'yyyyMMdd_HHmm') + "-MicrosoftStoreUpdate.log"
    $script:LogFileWindowsUpdate = (Get-Date -Format 'yyyyMMdd_HHmm') + "-WindowsUpdate.log"
}

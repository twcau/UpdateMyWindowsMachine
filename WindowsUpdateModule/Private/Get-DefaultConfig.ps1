function Get-DefaultConfig {
    <#
    .SYNOPSIS
        Returns a fully populated, bulletproof default config hashtable for the update automation system.
    #>
    [CmdletBinding()]
    param()
    $defaultConfig = @{
        LogDir                  = "$PSScriptRoot/../Logs"
        UpdateSchedule          = 'Weekly'
        UpdateDay               = 'Sunday'
        UpdateTime              = '21:30'
        EnableStoreUpdates      = $true
        EnableOfficeUpdates     = $true
        EnableThirdPartyUpdates = $true
        DaysToKeep              = 7
        ArchiveRetentionDays    = 90
        ShowLevelOnScreen       = $false
        ShowTimestampOnScreen   = $false
        TimeoutSeconds          = 60
        UpdateTypes             = @('Windows','Office','Winget','PatchMyPC')
        wingetSkipList          = @()
        ScheduledTask           = @{
            Enabled    = $true
            Frequency  = 'Weekly'
            Time       = '21:30'
            DayOfWeek  = 'Sunday'
            DayOfMonth = $null
            NthWeek    = $null
            NthWeekday = $null
        }
    }
    return $defaultConfig
}

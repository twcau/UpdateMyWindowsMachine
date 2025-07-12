Describe 'Start-FirstTimeSetup' {
    It 'should return a hashtable config on success' {
        $mockConfig = @{ LogDir = 'C:\Logs'; DaysToKeep = 7; ArchiveRetentionDays = 30; ShowLevelOnScreen = $true; ShowTimestampOnScreen = $true; TimeoutSeconds = 60; UpdateTypes = @('Windows', 'Office'); wingetSkipList = @(); ScheduledTask = @{ Enabled = $false; Frequency = 'Daily'; Time = '02:00'; DayOfWeek = 'Monday'; DayOfMonth = 1; NthWeek = ''; NthWeekday = '' } }
        Mock Get-Config { $mockConfig }
        Mock Save-Config {}
        Mock Register-WindowsUpdateScheduledTask {}
        Mock Write-Log {}
        Mock Invoke-PromptOrDefault { param($Prompt, $Current, $HardDefault) $Current }
        Mock ConvertTo-YNString { param($val) 'Y' }
        Mock Show-SettingsSummary {}
        Mock Get-PatchMyPCInfo { @{ Installed = $true } }
        $result = Start-FirstTimeSetup
        $result | Should -BeOfType 'hashtable'
        $result.LogDir | Should -Be 'C:\Logs'
    }
    It 'should log and return $null if config is not a hashtable' {
        Mock Get-Config { @() }
        Mock Save-Config {}
        Mock Register-WindowsUpdateScheduledTask {}
        Mock Write-Log {}
        Mock Invoke-PromptOrDefault { param($Prompt, $Current, $HardDefault) $Current }
        Mock ConvertTo-YNString { param($val) 'Y' }
        Mock Show-SettingsSummary {}
        Mock Get-PatchMyPCInfo { @{ Installed = $true } }
        $result = Start-FirstTimeSetup
        $result | Should -Be $null
    }
}

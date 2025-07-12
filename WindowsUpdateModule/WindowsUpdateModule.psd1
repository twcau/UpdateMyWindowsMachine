@{
    RootModule        = ''
    ModuleVersion     = '1.1.0'
    GUID              = 'b1e2c7e2-1e2b-4e2a-9e2b-1e2b4e2a9e2b'
    Author            = 'Michael Harris'
    CompanyName       = 'twcau'
    Copyright         = '(C) 2025 Michael H.'
    Description       = 'Modular PowerShell module for Windows, Office, Store, and third-party update automation.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-Config',
        'Save-Config',
        'Set-GlobalsFromConfig',
        'Run-AllUpdates',
        'Register-WindowsUpdateScheduledTask',
        'Start-FirstTimeSetup',
        'Show-MainMenu',
        'Show-ConfigMenu',
        'Invoke-PromptOrDefault',
        'ConvertTo-YNString',
        'Show-SettingsSummary',
        'Format-DayOfWeek',
        'Format-Frequency',
        'Format-TimeString'
    )
    PrivateData       = @{
        PSData = @{
            Tags         = @('Windows', 'Update', 'Automation', 'Module')
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = 'v1.1.0: Centralized prompt logic, improved error handling, expanded documentation, and more Pester tests.'
        }
    }
}

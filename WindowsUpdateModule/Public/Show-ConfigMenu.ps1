function Show-ConfigMenu {
    <#
    .SYNOPSIS
        Displays and optionally edits the current configuration.
    .DESCRIPTION
        Shows the current config, allows editing or re-running setup, and returns to main menu.
    .PARAMETER JsonConfigPath
        Path to the config JSON file.
    .PARAMETER OldConfigPath
        Path to the old config file (optional).
    .PARAMETER DefaultConfig
        The default config hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$JsonConfigPath,
        [Parameter()]
        [string]$OldConfigPath,
        [Parameter()]
        [hashtable]$DefaultConfig
    )
    . "$PSScriptRoot\..\Private\Repair-Config.ps1"
    . "$PSScriptRoot\..\Private\Get-DefaultConfig.ps1"
    $defaultConfig = Get-DefaultConfig
    Clear-Host
    $config = Get-Config -JsonConfigPath $JsonConfigPath -OldConfigPath $OldConfigPath -DefaultConfig $defaultConfig
    $config = Repair-Config -Config $config -DefaultConfig $defaultConfig
    if ($config -is [System.Object[]]) {
        $config = $config | Where-Object { $_ -is [System.Collections.Hashtable] } | Select-Object -First 1
    }
    Set-GlobalsFromConfig $config
    Write-Host ""
    Write-Log "==== Current Configuration ====" "HEADER" -SuppressLogFile
    Write-Host ""
    Write-Log ($config | ConvertTo-Json -Depth 5) "INFO" -SuppressLogFile
    Write-Host ""
    Write-Log "Would you like to edit the config (E), re-run first-time setup (S), or exit (X)? (E/S/X)" "ASK" -SuppressLogFile
    $edit = Read-HostIfInteractive "Edit config (E), Setup (S), or Exit (X)?"
    if ($edit -match '^(E|e)') {
        notepad $JsonConfigPath
        Write-Log "Press Enter when done editing to reload config..." "ASK" -SuppressLogFile
        [void][System.Console]::ReadLine()
        $config = Get-Config -JsonConfigPath $JsonConfigPath -OldConfigPath $OldConfigPath -DefaultConfig $DefaultConfig
        if ($config -is [System.Object[]]) {
            $config = $config | Where-Object { $_ -is [System.Collections.Hashtable] } | Select-Object -First 1
        }
        Set-GlobalsFromConfig $config
        Write-Log "Config reloaded after edit." "SUCCESS"
    }
    elseif ($edit -match '^(S|s)') {
        $config = Start-FirstTimeSetup -JsonConfigPath $JsonConfigPath -OldConfigPath $OldConfigPath -DefaultConfig $defaultConfig
        if ($config -is [System.Object[]]) {
            $config = $config | Where-Object { $_ -is [System.Collections.Hashtable] } | Select-Object -First 1
        }
        # Always save config to the correct file after setup
        Save-Config -Config $config -JsonConfigPath $JsonConfigPath
        Set-GlobalsFromConfig $config
        Write-Log "Config saved after first-time setup." "SUCCESS"
    }
    # After viewing/editing, return to main menu
}

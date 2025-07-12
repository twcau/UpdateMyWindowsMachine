function Show-MainMenu {
    <#
    .SYNOPSIS
        Displays the main menu for Windows Update Automation.
    .DESCRIPTION
        Allows the user to run updates, view/edit config, or exit.
    .PARAMETER JsonConfigPath
        Path to the config JSON file.
    .PARAMETER OldConfigPath
        Path to the old config file (optional).
    .PARAMETER DefaultConfig
        The default config hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$JsonConfigPath,
        [Parameter()]
        [string]$OldConfigPath,
        [Parameter()]
        [hashtable]$DefaultConfig
    )
    . "$PSScriptRoot\..\Private\Repair-Config.ps1"
    . "$PSScriptRoot\..\Private\Get-DefaultConfig.ps1"
    $defaultConfig = Get-DefaultConfig
    while ($true) {
        Write-Log "==== Windows Update Automation Main Menu ====" "HEADER" -SuppressLogFile
        Write-Log "1. Run updates now" "INFO" -SuppressLogFile
        Write-Log "2. View/Edit configuration" "INFO" -SuppressLogFile
        Write-Log "3. Exit" "INFO" -SuppressLogFile
        $choice = Read-Host "Select an option (1-3)"
        switch ($choice) {
            '1' { Run-AllUpdates }
            '2' { Show-ConfigMenu -JsonConfigPath $JsonConfigPath -OldConfigPath $OldConfigPath -DefaultConfig $defaultConfig }
            '3' { return }
            default { Write-Log "Invalid selection. Please enter 1, 2, or 3." "WARN" -SuppressLogFile }
        }
    }
}

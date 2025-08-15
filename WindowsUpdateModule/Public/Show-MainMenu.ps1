function Show-MainMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$JsonConfigPath,
        [Parameter(Mandatory = $false)]
        [string]$OldConfigPath,
        [Parameter(Mandatory = $false)]
        [hashtable]$DefaultConfig,
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
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
    . "$PSScriptRoot\..\Private\Repair-Config.ps1"
    . "$PSScriptRoot\..\Private\Get-DefaultConfig.ps1"
    $defaultConfig = Get-DefaultConfig
    while ($true) {
        Clear-Host
        if ($script:DebugMode) {
            Write-Host "[DEBUG] Pausing briefly before showing menu..."
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        Write-Log "==== Windows Update Automation Main Menu ====" "HEADER" -SuppressLogFile
        Write-Host ""
        Write-Log "1. Run updates now" "INFO" -SuppressLogFile
        Write-Log "2. View/Edit configuration" "INFO" -SuppressLogFile
        Write-Log "3. Exit" "INFO" -SuppressLogFile
        Write-Host ""
        $choice = Read-HostIfInteractive "Select an option (1-3)"
        switch ($choice) {
            '1' {
                Invoke-AllUpdates -Config $Config -LogFilePath $LogFilePath -ScriptDebug:$script:DebugMode
                # Pause for user input after updates before clearing the screen (single prompt only)
                Read-HostIfInteractive "Press Enter to return to main menu..."
            }
            '2' { Show-ConfigMenu -JsonConfigPath $JsonConfigPath -OldConfigPath $OldConfigPath -DefaultConfig $defaultConfig }
            '3' { return }
            default { Write-Log "Invalid selection. Please enter 1, 2, or 3." "WARN" -SuppressLogFile }
        }
    }
}
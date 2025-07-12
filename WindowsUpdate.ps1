<#
    .TITLE
    Update My PC - Microsoft Windows, Store, and Office Update Automation Script
    .AUTHOR
    Michael Harris (https://github.com/twcau)
    Copyright (C) 2025.
    Usage rights per the license file in the root of this repository.
    .SYNOPSIS
    Script to check for and install all Windows Updates, Microsoft Store, and Microsoft Office updates automatically, and leverage PatchMyPC to update other applications. Some feature may not work in a non-interactive session (Session 0).
    .DESCRIPTION
    This PowerShell script is designed to be run via Windows Task Scheduler to automate the process of checking for and installing all available Windows Updates, Microsoft Store updates, and Microsoft Office updates.
    .NOTES
    Script to be triggered by Windows Task Manager, to check for and install all Windows Updates, Microsoft Store, and Office updates automatically.
    Script intended to be triggered on Sunday evening after the machine's 2130hrs power on.
    Unsigned scripts need to be enabled on the target device.
    .REFERENCES
    - https://www.itechtics.com/run-windows-update-cmd/#force-windows-update-check-using-run-command-box
    - https://www.makeuseof.com/enable-script-execution-policy-windows-powershell/
#>

# Entry point for UpdateMyWindowsMachine
# Loads the WindowsUpdateModule and starts the menu or automation

Import-Module "$PSScriptRoot\WindowsUpdateModule\WindowsUpdateModule.psm1" -Force

# Set config variables for Get-Config
$jsonConfigPath = "$PSScriptRoot\WindowsUpdateConfig.json"
$oldConfigPath = "$PSScriptRoot\WindowsUpdateConfig.psd1"
. "$PSScriptRoot\WindowsUpdateModule\Private\Get-DefaultConfig.ps1"
$defaultConfig = Get-DefaultConfig

# Load config
$config = Get-Config -JsonConfigPath $jsonConfigPath -OldConfigPath $oldConfigPath -DefaultConfig $defaultConfig

# Set up log directory and file before any logging
if (-not $config -or -not $config.LogDir) {
    Write-Warning "Config or LogDir missing, using default log directory."
    $logDir = "$PSScriptRoot\Logs"
}
else {
    $logDir = $config.LogDir
}
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logDir ("UpdateLog_" + (Get-Date -Format 'yyyyMMdd') + ".log")

# Set globals from config
Set-GlobalsFromConfig $config

# After setting globals from config, clean up old logs
Remove-OldLogs -LogDir $logDir -DaysToKeep $config.DaysToKeep

# Auto-elevate if not running as admin (interactive session only)
$alreadyElevated = $false
$forceShowMenu = $false
if ($args -contains '-elevated') { $alreadyElevated = $true }
if ($args -contains '-showmenu') { $forceShowMenu = $true }
if (-not (Test-IsElevated)) {
    if (-not $alreadyElevated -and [System.Diagnostics.Process]::GetCurrentProcess().SessionId -ne 0 -and $env:SESSIONNAME -eq "Console") {
        Write-Log "Script is not running with administrative privileges. Attempting to relaunch as administrator..." "WARN" -PreBreak
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = (Get-Process -Id $PID).Path
        $psi.Arguments = '"' + $PSCommandPath + '" -elevated -showmenu'
        $psi.Verb = 'runas'
        $psi.UseShellExecute = $true
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            Write-Log "Script relaunched as administrator. Exiting current session..." "INFO"
        }
        catch {
            $err = $_
            Write-Log ("Failed to relaunch script as administrator: " + $err.Exception.Message) "ERROR" -PreBreak
        }
        exit
    }
}

# Main menu or automation
if ($forceShowMenu -or ([System.Diagnostics.Process]::GetCurrentProcess().SessionId -ne 0 -and $env:SESSIONNAME -eq "Console")) {
    $menuAction = Show-MainMenu -JsonConfigPath $jsonConfigPath -OldConfigPath $oldConfigPath -DefaultConfig $defaultConfig
    if ($menuAction -eq 'run') {
        Write-Log "User selected to run updates from main menu." "INFO"
        Run-AllUpdates
    }
    else {
        exit
    }
}
else {
    # If not interactive, always run updates
    Run-AllUpdates
}
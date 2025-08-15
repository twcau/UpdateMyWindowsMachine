
# Argument parsing
$jsonConfigPath = "$PSScriptRoot\WindowsUpdateConfig.json"
$oldConfigPath = "$PSScriptRoot\WindowsUpdateConfig-old.json"
$ScriptDebug = $false
foreach ($arg in $args) {
    if ($arg -ieq '-scriptdebug') { $ScriptDebug = $true }
    elseif ($arg -like '-jsonconfigpath=*') { $jsonConfigPath = $arg -replace '^-jsonconfigpath=', '' }
    elseif ($arg -like '-oldconfigpath=*') { $oldConfigPath = $arg -replace '^-oldconfigpath=', '' }
}


# Set up log directory and file after config is loaded
if (-not $config -or -not $config.LogDir) {
    Write-Warning "Config or LogDir missing, using default log directory."
    $logDir = "$PSScriptRoot\Logs"
}
else {
    $logDir = $config.LogDir
}
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$script:LogFile = Join-Path $logDir ("UpdateLog_" + (Get-Date -Format 'yyyyMMdd') + ".log")

# Set DebugMode global
$script:DebugMode = $ScriptDebug.IsPresent



# No param block; use $args exclusively for switch detection
$elevated = $false
$showmenu = $false
if ($args -contains '-elevated') { $elevated = $true }
if ($args -contains '-showmenu') { $showmenu = $true }

# Debug: After config/module loading, before menu logic
if ($script:DebugMode) {
    Write-Host ("[DEBUG] About to show main menu. Args: {0}, UMWM_AUTO: {1}" -f ($args -join ','), $env:UMWM_AUTO)
}
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



if ($script:DebugMode) {
    Write-Host "[DEBUG] Script started. PID: $PID, Host: $($Host.Name), Session: $env:SESSIONNAME, PSEdition: $($PSVersionTable.PSEdition), IsAdmin: $(([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
    try { $null = $Host.UI.RawUI.KeyAvailable; $isInteractive = $true } catch { $isInteractive = $false }
    if ($isInteractive) { try { Read-Host "[DEBUG] Script started. Press Enter to continue..." } catch {} }
}

#region Ensure PowerShell 7+ and Admin Privileges
function Test-PS7AndAdmin {
    <#
    .SYNOPSIS
        Ensures the script is running in PowerShell 7+ and as Administrator.
    .DESCRIPTION
        If not running in PowerShell 7+, relaunches in pwsh.exe as admin. If in pwsh but not admin, relaunches as admin. Only continues if both conditions are met.
    .NOTES
        This function must be called at the very top of the script. It will relaunch the script as needed and exit the current process.
    #>
    $isPS7 = $PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -ge 7
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $alreadyElevated = $args -contains '-elevated'
    # $forceShowMenu removed (was unused)
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
    if (-not $scriptPath) {
        Write-Host "[ERROR] Could not determine script path for elevation. Exiting." -ForegroundColor Red
        try { Read-Host "Press Enter to exit..." } catch {}
        exit 1
    }
    $allArgs = @()
    if ($MyInvocation.BoundParameters.Count -gt 0) {
        foreach ($k in $MyInvocation.BoundParameters.Keys) {
            $allArgs += "-$k"
            $allArgs += $MyInvocation.BoundParameters[$k]
        }
    }
    # Do not forward any arguments for elevation; only pass elevation/menu flags
    # Find pwsh.exe if needed
    $pwsh = $null
    if (-not $isPS7) {
        $env:UMWM_FORCE_MENU = 1
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
        if (-not $pwsh) {
            $possible = @(
                "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                "$env:ProgramFiles(x86)\PowerShell\7\pwsh.exe",
                "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
            )
            foreach ($path in $possible) { if (Test-Path $path) { $pwsh = $path; break } }
        }
        if (-not $pwsh) {
            Write-Host "PowerShell 7 (pwsh.exe) is required but was not found. Please install PowerShell 7+ from https://aka.ms/powershell. Exiting." -ForegroundColor Red
            try { Read-Host "Press Enter to exit..." } catch {}
            exit 1
        }
        $cmd = "& '" + $scriptPath.Replace("'", "''") + "' -elevated -showmenu; Read-Host 'Press Enter to close...'"
        try {
            Start-Process -FilePath $pwsh -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd -Verb runas -WindowStyle Normal
            Write-Host "Script relaunched in new console as administrator. Exiting current session..." -ForegroundColor Yellow
            if ($script:DebugMode) { try { Read-Host "[DEBUG] Relaunching. Press Enter to exit..." } catch {} }
            exit
        }
        catch {
            Write-Host "Elevation cancelled by user or failed. Exiting script..." -ForegroundColor Red
            if ($script:DebugMode) { try { Read-Host "[DEBUG] Elevation cancelled. Press Enter to exit..." } catch {} }
            exit 1
        }
    }
    elseif (-not $isAdmin -and -not $alreadyElevated) {
        $env:UMWM_FORCE_MENU = 1
        $pwshPath = (Get-Process -Id $PID).Path
        $cmd = "& '" + $scriptPath.Replace("'", "''") + "' -elevated -showmenu; Read-Host 'Press Enter to close...'"
        try {
            Start-Process -FilePath $pwshPath -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd -Verb runas -WindowStyle Normal
            Write-Host "Script relaunched in new console as administrator. Exiting current session..." -ForegroundColor Yellow
            if ($script:DebugMode) { try { Read-Host "[DEBUG] Relaunching. Press Enter to exit..." } catch {} }
            exit
        }
        catch {
            Write-Host "Elevation cancelled by user or failed. Exiting script..." -ForegroundColor Red
            if ($script:DebugMode) { try { Read-Host "[DEBUG] Elevation cancelled. Press Enter to exit..." } catch {} }
            exit 1
        }
    }
}
Test-PS7AndAdmin
#endregion

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


# Set up log directory and file after config is loaded
if (-not $config -or -not $config.LogDir) {
    Write-Warning "Config or LogDir missing, using default log directory."
    $logDir = "$PSScriptRoot\Logs"
}
else {
    $logDir = $config.LogDir
    if (-not [System.IO.Path]::IsPathRooted($logDir)) {
        $logDir = Join-Path $PSScriptRoot $logDir
    }
}
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$script:LogFile = Join-Path $logDir ("UpdateLog_" + (Get-Date -Format 'yyyyMMdd') + ".log")

# Set globals from config
Set-GlobalsFromConfig $config

# After setting globals from config, clean up old logs
Remove-OldLogs -LogDir $logDir -DaysToKeep $config.DaysToKeep


# Main menu or automation
# Always show menu unless -auto or $env:UMWM_AUTO is set (for scheduled/automation runs only)
if ($args -contains '-auto' -or $env:UMWM_AUTO) {
    Invoke-AllUpdates
}
else {
    $menuShown = $false
    try {
        $menuAction = Show-MainMenu -JsonConfigPath $jsonConfigPath -OldConfigPath $oldConfigPath -DefaultConfig $defaultConfig -Config $config -LogFilePath $script:LogFile
        $menuShown = $true
    }
    catch {
        if ($script:DebugMode) { Write-Host "[DEBUG] Menu did not show due to: $_. Forcing fallback menu window..." -ForegroundColor Yellow }
        $menuShown = $false
    }
    if (-not $menuShown) {
        # Fallback: forcibly launch a new PowerShell 7 window with the menu
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
        if (-not $pwsh) {
            $possible = @(
                "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                "$env:ProgramFiles(x86)\PowerShell\7\pwsh.exe",
                "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
            )
            foreach ($path in $possible) { if (Test-Path $path) { $pwsh = $path; break } }
        }
        if (-not $pwsh) {
            Write-Host "PowerShell 7 (pwsh.exe) is required but was not found. Please install PowerShell 7+ from https://aka.ms/powershell. Exiting." -ForegroundColor Red
            try { Read-Host "Press Enter to exit..." } catch {}
            exit 1
        }
        $cmd = "& `$scriptPath @('-elevated','-showmenu'); Read-Host '[DEBUG] Script ending. Press Enter to close...'"
        if ($script:DebugMode) { Write-Host "[DEBUG] Launching fallback menu window..." -ForegroundColor Yellow }
        Start-Process -FilePath $pwsh -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd -Verb runas -WindowStyle Normal -Wait
        if ($script:DebugMode) { Write-Host "[DEBUG] Fallback menu window closed. Exiting parent script." -ForegroundColor Yellow }
        exit
    }
    if ($menuAction -eq 'run') {
        Write-Log "User selected to run updates from main menu." "INFO"
        Invoke-AllUpdates
    }
    else {
        exit
    }
}



# Always pause at the end if running in an elevated fallback/menu window
if ($args -contains '-elevated' -and $args -contains '-showmenu') {
    if ($script:DebugMode) { try { Read-Host "[DEBUG] Script ending. Press Enter to close..." } catch {} }
}
else {
    if ($script:DebugMode) {
        Write-Host "[DEBUG] Script ending. PID: $PID, Host: $($Host.Name), Session: $env:SESSIONNAME, PSEdition: $($PSVersionTable.PSEdition), IsAdmin: $(([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
        try { $null = $Host.UI.RawUI.KeyAvailable; $isInteractive = $true } catch { $isInteractive = $false }
        if ($isInteractive) {
            try { Read-Host "[DEBUG] Script ending. Press Enter to close..." } catch {}
        }
        else {
            # Launch a new PowerShell window with a pause so the user can see debug output
            $msg = '[DEBUG] Script ended in non-interactive/elevated context. Press any key to close...'
            $debugOut = @(
                "[DEBUG] Script ending. PID: $PID, Host: $($Host.Name), Session: $env:SESSIONNAME, PSEdition: $($PSVersionTable.PSEdition), IsAdmin: $(([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))",
                $msg
            ) -join "`n"
            $pauseCmd = "Write-Host '$debugOut'; pause"
            Start-Process powershell -ArgumentList "-NoExit", "-Command", $pauseCmd -WindowStyle Normal
        }
    }
}
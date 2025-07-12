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

# =====================
# FUNCTION DEFINITIONS (move all to top for scope and clarity)
# =====================

# NOTE: Configuration
# =====================
# CONFIGURATION MANAGEMENT AND FIRST-TIME SETUP FUNCTIONS
# =====================

# NOTE: Configuration Functions - Save-Config
function Save-Config($config) {
    $json = $config | ConvertTo-Json -Depth 5
    Set-Content -Path $jsonConfigPath -Value $json -Encoding UTF8
}

# NOTE: Configuration Functions - Get-Config
function Get-Config {
    # Migrate from old psd1 if needed
    if ((Test-Path $oldConfigPath) -and -not (Test-Path $jsonConfigPath)) {
        try {
            $psd1Config = Import-PowerShellDataFile $oldConfigPath
            $psd1Config | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonConfigPath -Encoding UTF8
            Remove-Item $oldConfigPath -Force
        }
        catch {
            Write-Log "Could not parse legacy .psd1 config. Using default config and recreating as JSON. If you had custom settings, please reconfigure via the menu." "WARN"
            Save-Config $defaultConfig
            return $defaultConfig
        }
    }
    if (Test-Path $jsonConfigPath) {
        try {
            $config = Get-Content $jsonConfigPath -Raw | ConvertFrom-Json
            # Convert PSCustomObject to hashtable for mutability
            $config = $config | ConvertTo-Json -Depth 5 | ConvertFrom-Json -AsHashtable
            return $config
        }
        catch {
            Write-Log "Failed to load config file. Recreating with defaults." "WARN"
            Save-Config $defaultConfig
            return $defaultConfig
        }
    }
    else {
        Save-Config $defaultConfig
        return $defaultConfig
    }
}

# NOTE: Configuration Functions - Test-LogDirAndFile
# Robust log directory and file handling
function Test-LogDirAndFile {
    param([string]$logDir)
    $logDir = $logDir.Trim()
    if ([string]::IsNullOrWhiteSpace($logDir)) {
        $logDir = Join-Path $scriptDir 'Logs'
    }
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        catch {
            $logDir = Join-Path $env:TEMP 'WindowsUpdateLogs'
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
        }
    }
    return $logDir
}

# NOTE: Configuration Functions - Normalize-DayOfWeek
# =====================
# DAY OF WEEK NORMALIZATION
# =====================
function Normalize-DayOfWeek {
    param(
        [Parameter(Mandatory)]
        [string]$InputDay
    )
    if (-not $InputDay) { return $null }
    $days = @{ 'M' = 'Monday'; 'Mo' = 'Monday'; 'Mon' = 'Monday';
        'T' = 'Tuesday'; 'Tu' = 'Tuesday'; 'Tue' = 'Tuesday';
        'W' = 'Wednesday'; 'We' = 'Wednesday'; 'Wed' = 'Wednesday';
        'Th' = 'Thursday'; 'Thu' = 'Thursday';
        'F' = 'Friday'; 'Fr' = 'Friday'; 'Fri' = 'Friday';
        'Sa' = 'Saturday'; 'Sat' = 'Saturday';
        'Su' = 'Sunday'; 'Sun' = 'Sunday' 
    }
    $input = $InputDay.Trim()
    if ($days.ContainsKey($input)) { return $days[$input] }
    $input = $input.Substring(0, 1).ToUpper() + $input.Substring(1).ToLower()
    if ($days.Values -contains $input) { return $input }
    return $null
}

# NOTE: Configuration Functions - Normalize-TimeString
# =====================
# TIME NORMALIZATION
# =====================
function Normalize-TimeString {
    param(
        [Parameter(Mandatory)]
        [string]$InputTime,
        [string]$DefaultTime = '21:30'
    )
    if (-not $InputTime) { return $DefaultTime }
    $t = $InputTime.Trim()
    # Accept HH:mm
    if ($t -match '^(\d{1,2}):(\d{2})$') {
        $h = [int]($t -split ':' | Select-Object -First 1)
        $m = [int]($t -split ':' | Select-Object -Last 1)
        if ($h -ge 0 -and $h -le 23 -and $m -ge 0 -and $m -le 59) { return "{0:D2}:{1:D2}" -f $h, $m }
    }
    # Accept HHmm or HMM
    if ($t -match '^(\d{3,4})$') {
        $h = [int]($t.Substring(0, $t.Length - 2))
        $m = [int]($t.Substring($t.Length - 2, 2))
        if ($h -ge 0 -and $h -le 23 -and $m -ge 0 -and $m -le 59) { return "{0:D2}:{1:D2}" -f $h, $m }
    }
    # Accept H or HH
    if ($t -match '^(\d{1,2})$') {
        $h = [int]$t
        if ($h -ge 0 -and $h -le 23) { return "{0:D2}:00" -f $h }
    }
    # Accept H:MMam/pm or H:MM am/pm
    if ($t -match '^(\d{1,2}):(\d{2})\s*(am|pm|AM|PM)$') {
        $h = [int]($t -split ':' | Select-Object -First 1)
        $m = [int](($t -split ':' | Select-Object -Last 1) -replace '[^0-9]', '')
        $ampm = $t -replace '.*(am|pm|AM|PM)$', '$1'
        if ($ampm -match '^(pm|PM)$' -and $h -lt 12) { $h += 12 }
        if ($ampm -match '^(am|AM)$' -and $h -eq 12) { $h = 0 }
        if ($h -ge 0 -and $h -le 23 -and $m -ge 0 -and $m -le 59) { return "{0:D2}:{1:D2}" -f $h, $m }
    }
    # Accept H am/pm or HH am/pm
    if ($t -match '^(\d{1,2})\s*(am|pm|AM|PM)$') {
        $h = [int]($t -replace '\D.*$', '')
        $m = 0
        $ampm = $t -replace '.*(am|pm|AM|PM)$', '$1'
        if ($ampm -match '^(pm|PM)$' -and $h -lt 12) { $h += 12 }
        if ($ampm -match '^(am|AM)$' -and $h -eq 12) { $h = 0 }
        if ($h -ge 0 -and $h -le 23) { return "{0:D2}:00" -f $h }
    }
    # Fallback
    return $DefaultTime
}

# NOTE: Configuration Functions - Normalize-Frequency
# =====================
# SCHEDULE FREQUENCY NORMALIZATION
# =====================
function Normalize-Frequency {
    param([string]$input)
    if (-not $input) { return $null }
    $val = $input.Trim().ToLower()
    switch ($val) {
        'd' { return 'Daily' }
        'daily' { return 'Daily' }
        'w' { return 'Weekly' }
        'weekly' { return 'Weekly' }
        'm' { return 'Monthly' }
        'monthly' { return 'Monthly' }
        default { return $null }
    }
}

# NOTE: Configuration Functions - Register-WindowsUpdateScheduledTask
# =====================
# SCHEDULED TASK CREATION/UPDATE
# =====================
function Register-WindowsUpdateScheduledTask {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    $taskName = "WindowsUpdateAutomation"
    $scriptPath = $PSCommandPath
    $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File `"$scriptPath`""
    $trigger = $null
    $freq = $Config.ScheduledTask.Frequency
    $time = $Config.ScheduledTask.Time
    $dayOfWeek = $Config.ScheduledTask.DayOfWeek
    $dayOfMonth = $Config.ScheduledTask.DayOfMonth
    $nthWeek = $Config.ScheduledTask.NthWeek
    $nthWeekday = $Config.ScheduledTask.NthWeekday
    if ($freq -eq 'Daily') {
        if ($dayOfWeek) {
            $trigger = New-ScheduledTaskTrigger -Daily -At $time -DaysInterval 1
            $trigger.DaysOfWeek = $dayOfWeek
        }
        else {
            $trigger = New-ScheduledTaskTrigger -Daily -At $time
        }
    }
    elseif ($freq -eq 'Weekly') {
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dayOfWeek -At $time
    }
    elseif ($freq -eq 'Monthly') {
        if ($dayOfMonth) {
            $trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth $dayOfMonth -At $time
        }
        elseif ($nthWeek -and $nthWeekday) {
            $trigger = New-ScheduledTaskTrigger -Monthly -WeeksOfMonth $nthWeek -DaysOfWeek $nthWeekday -At $time
        }
        else {
            Write-Log "Monthly schedule missing day of month or Nth weekday info." "ERROR"
            return
        }
    }
    else {
        Write-Log "Unknown schedule frequency: $freq" "ERROR"
        return
    }
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    try {
        if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings
        Write-Log "Scheduled task '$taskName' created/updated successfully." "SUCCESS"
    }
    catch {
        $err = $_
        Write-Log ("Failed to create/update scheduled task: " + $err.Exception.Message) "ERROR"
    }
}

# =====================
# CONFIGURATION MANAGEMENT AND FIRST-TIME SETUP (JSON-based)
# =====================

# NOTE: Configuration - Paths to config files
# Path to config file (same folder as script)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$jsonConfigPath = Join-Path $scriptDir 'WindowsUpdateConfig.json'
$oldConfigPath = Join-Path $scriptDir 'WindowsUpdateConfig.psd1'

# NOTE: Configuration - Default config values
# Default config values
$defaultConfig = @{
    logDir                     = 'C:\PSScripts\Logs\WindowsUpdate'
    DaysToKeep                 = 7
    ArchiveRetentionDays       = 14
    ShowLevelOnScreen          = $false
    ShowTimestampOnScreenentry = $false
    TimeoutSeconds             = 60
    UpdateTypes                = @('Windows', 'Office', 'Winget')
    wingetSkipList             = @(
        'Teams Machine-Wide Installer',
        'Microsoft.Teams.Classic',
        'Teams classic',
        'XP8BT8DW290MPQ'
    )
    ScheduledTask              = @{
        Enabled   = $false
        Frequency = 'Weekly'
        Time      = '21:30'
        DayOfWeek = 'Sunday'
    }
}

# NOTE: Core Functions - Write-Log
function Write-Log {
    <#
    .SYNOPSIS
        Writes a log entry to the terminal and to a persistent log file.
    .DESCRIPTION
        Supports color, log levels, and optional timestamp display on screen.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        The log level (INFO, HEADER, NOTIFY, SUCCESS, WARN, ERROR, ASK).
    .PARAMETER PreBreak
        Adds a blank line before the log entry on screen.
    .PARAMETER PostBreak
        Adds a blank line after the log entry on screen.
    .PARAMETER ShowTimestampOnScreenentry
        If set, includes the timestamp in the terminal output.
    .PARAMETER SuppressLogFile
        If set, does not write this entry to the log file (for menu UI lines).
    #>
    param (
        [string]$Message,
        [ValidateSet("INFO", "HEADER", "NOTIFY", "SUCCESS", "WARN", "ERROR", "ASK")]
        [string]$Level = "INFO",
        [switch]$PreBreak,
        [switch]$PostBreak,
        [switch]$ShowTimestampOnScreenentry = $false,
        [switch]$SuppressLogFile
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    $screenEntry = ""
    if ($ShowTimestampOnScreenentry) { $screenEntry += "[$timestamp]" }
    if ($script:ShowLevelOnScreen) { $screenEntry += "[$Level] " }
    $screenEntry += $Message

    ## Terminal output with optional line breaks and color
    if ($PreBreak) { Write-Host "" }
    switch ($Level) {
        "HEADER" {
            [System.Console]::ResetColor()
            Write-Host $screenEntry -ForegroundColor White -BackgroundColor Blue
            [System.Console]::ResetColor()
            Write-Host ""
        }
        "NOTIFY" {
            Write-Host $screenEntry -ForegroundColor Yellow
            [System.Console]::ResetColor()
        }
        "SUCCESS" {
            Write-Host $screenEntry -ForegroundColor Green
            [System.Console]::ResetColor()
        }
        "WARN" {
            Write-Host $screenEntry -ForegroundColor Yellow -BackgroundColor Black
            [System.Console]::ResetColor()
        }
        "ERROR" {
            Write-Host $screenEntry -ForegroundColor Red
            [System.Console]::ResetColor()
        }
        "ASK" {
            Write-Host $screenEntry -ForegroundColor White
            [System.Console]::ResetColor()
        }
        default { Write-Host $screenEntry }
    }
    if ($PostBreak) { Write-Host "" }
    try {
        if (-not $SuppressLogFile -and $logFile -and (Test-Path (Split-Path $logFile -Parent))) {
            Add-Content -Path $logFile -Value $logEntry
        }
        elseif (-not $SuppressLogFile) {
            Write-Host "[LOGGING WARNING] Could not write to log file: $logFile" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[LOGGING ERROR] Failed to write to log file: $logFile" -ForegroundColor Red
    }
}

# NOTE: Core Functions - Get-PatchMyPCInfo
function Get-PatchMyPCInfo {
    <#
    .SYNOPSIS
        Checks if Patch My PC is installed and how it can be called (alias, path, or not installed).
    .OUTPUTS
        [PSCustomObject] with properties: Installed (bool), AliasAvailable (bool), Path (string or $null)
    #>
    $aliasAvailable = $false
    if (Get-Command 'patch-my-pc' -ErrorAction SilentlyContinue) {
        $aliasAvailable = $true
    }
    $defaultPath = "C:\\Program Files\\Patch My PC\\Patch My PC Home Updater\\updater.exe"
    $patchPath = $null
    if (Test-Path $defaultPath) {
        $patchPath = $defaultPath
    }
    if (-not $aliasAvailable -and -not $patchPath) {
        $env:PATH.Split(';') | ForEach-Object {
            $candidate = Join-Path $_ 'patch-my-pc.exe'
            if (Test-Path $candidate) { $patchPath = $candidate }
        }
    }
    [PSCustomObject]@{
        Installed      = ($aliasAvailable -or $patchPath)
        AliasAvailable = $aliasAvailable
        Path           = $patchPath
    }
}

# NOTE: Core Functions - Add-ToolLogToMainLog
function Add-ToolLogToMainLog {
    param(
        [Parameter(Mandatory)]
        [string]$ToolLogPath,
        [Parameter(Mandatory)]
        [string]$MainLogPath,
        [string]$Header = "Tool Output"
    )
    if (Test-Path $ToolLogPath) {
        $toolLogContent = Get-Content $ToolLogPath -Raw
        if ($toolLogContent) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $headerLine = "[$timestamp][INFO] ===== $Header ====="
            Add-Content -Path $MainLogPath -Value $headerLine
            Add-Content -Path $MainLogPath -Value $toolLogContent
            Add-Content -Path $MainLogPath -Value ("[$timestamp][INFO] ===== End $Header =====")
        }
    }
}

# NOTE: Core Functions - Test-IsElevated
function Test-IsElevated {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# NOTE: Core Functions - Run-AllUpdates
function Run-AllUpdates {
    # Windows Update
    if ($UpdateTypes -contains 'Windows') {
        if (-not (Test-IsElevated)) {
            Write-Log "Windows Update requires administrative privileges. Please run this script as Administrator to perform Windows Update." "ERROR" -PreBreak -PostBreak
        }
        else {
            Write-Log "Commencing Windows Update process..." "NOTIFY" -PreBreak
            try {
                Get-WindowsUpdate -AcceptAll -Install -AutoReboot | Tee-Object "$logDir\$logFileWindowsUpdate"
                Write-Log "Windows update completed." "SUCCESS"
            }
            catch {
                $err = $_
                Write-Log ("Windows Update failed: " + $err.Exception.Message) "ERROR" -PreBreak
            }
        }
    }
    else {
        Write-Log "Skipping Windows Update as per configuration." "INFO"
    }

    # Microsoft Office Update
    if ($UpdateTypes -contains 'Office') {
        Write-Log "Commencing Microsoft Office update process..." "NOTIFY" -PreBreak
        $officeApps = @('WINWORD', 'EXCEL', 'POWERPNT', 'OUTLOOK', 'ONENOTE', 'MSACCESS', 'MSPUB', 'VISIO', 'LYNC')
        $runningApps = Get-Process | Where-Object { $officeApps -contains $_.ProcessName } | Select-Object -ExpandProperty ProcessName -Unique
        if ($runningApps) {
            Write-Log "The following Office apps are running and will be closed: $($runningApps -join ', ')" "WARN"
            foreach ($app in $runningApps) {
                try {
                    Stop-Process -Name $app -Force -ErrorAction Stop
                    Write-Log "Closed $app." "SUCCESS"
                }
                catch {
                    $err = $_
                    Write-Log ("Failed to close ${app}: " + $err.Exception.Message) "ERROR"
                }
            }
        }
        else {
            Write-Log "No running Office apps detected." "SUCCESS"
        }
        # Locate OfficeC2RClient.exe robustly
        $officeC2R = $null
        $possiblePaths = @(
            "${env:ProgramFiles}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe",
            "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        )
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $officeC2R = $path
                break
            }
        }
        if (-not $officeC2R) {
            $searchRoots = @("${env:ProgramFiles}", "${env:ProgramFiles(x86)}")
            foreach ($root in $searchRoots) {
                try {
                    $found = Get-ChildItem -Path $root -Filter OfficeC2RClient.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($found) {
                        $officeC2R = $found.FullName
                        break
                    }
                }
                catch {
                    $err = $_
                    Write-Log ("Error searching for OfficeC2RClient.exe: " + $err.Exception.Message) "ERROR"
                }
            }
        }
        if ($officeC2R) {
            try {
                Write-Log "Starting Office update (silent, forced) using $officeC2R..." "NOTIFY" -PreBreak
                $updateProcess = Start-Process -FilePath $officeC2R -ArgumentList "/update user displaylevel=false forceappshutdown=true" -Wait -PassThru -WindowStyle Hidden
                if ($updateProcess.ExitCode -eq 0) {
                    Write-Log "Microsoft Office update completed successfully." "SUCCESS"
                }
                else {
                    Write-Log ("Microsoft Office update process exited with code " + $updateProcess.ExitCode) "ERROR" -PreBreak
                }
            }
            catch {
                $err = $_
                Write-Log ("Failed to start Office update: " + $err.Exception.Message) "ERROR" -PreBreak
            }
        }
        else {
            Write-Log "Office Click-to-Run client not found. Office update skipped." "WARN" -PreBreak
        }
    }
    else {
        Write-Log "Skipping Microsoft Office Update as per configuration." "INFO"
    }

    # Winget Update
    if ($UpdateTypes -contains 'Winget') {
        if ([System.Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0) {
            Write-Log "Running Microsoft Store update in SYSTEM session: Only Win32 apps will be updated (Store apps require user session)." "WARN" -PreBreak
            $wingetArgs = 'upgrade --source winget --accept-source-agreements --accept-package-agreements'
        }
        else {
            Write-Log "Commencing Microsoft Store update process, using winget..." "NOTIFY" -PreBreak
            $wingetArgs = 'upgrade --accept-source-agreements --accept-package-agreements'
        }
        $wingetListRaw = winget upgrade $wingetArgs | Select-String -Pattern "^(.*?)\s{2,}(.*?)\s{2,}(.*?)\s{2,}(.*?)\s{2,}(.*?)$" | ForEach-Object {
            $fields = $_.Line -split "\s{2,}"
            if ($fields.Count -ge 5) {
                [PSCustomObject]@{
                    Name      = $fields[0].Trim()
                    Id        = $fields[1].Trim()
                    Version   = $fields[2].Trim()
                    Available = $fields[3].Trim()
                    Source    = $fields[4].Trim()
                }
            }
        }
        $appsToUpgrade = $wingetListRaw | Where-Object {
            $skip = $false
            foreach ($skipItem in $wingetSkipList) {
                if ($_.Name -like "*$skipItem*" -or $_.Id -like "*$skipItem*") {
                    $skip = $true
                    break
                }
            }
            -not $skip
        }
        if ($appsToUpgrade) {
            foreach ($app in $appsToUpgrade) {
                Write-Log "Upgrading $($app.Name) ($($app.Id))..." "NOTIFY"
                try {
                    winget upgrade --id "$($app.Id)" --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Null
                    Write-Log "Upgraded $($app.Name) ($($app.Id))." "SUCCESS"
                }
                catch {
                    $err = $_
                    Write-Log ("Failed to upgrade $($app.Name): " + $err.Exception.Message) "ERROR"
                }
            }
        }
        else {
            Write-Log "No upgradable apps found (after skip list applied)." "INFO"
        }
    }
    else {
        Write-Log "Skipping Winget Update as per configuration." "INFO"
    }

    # Patch My PC Update
    if ($UpdateTypes -contains 'PatchMyPC') {
        Write-Log "Commencing Patch My PC update process..." "NOTIFY" -PreBreak
        $patchInfo = Get-PatchMyPCInfo
        if ($patchInfo.Installed) {
            try {
                if ($env:SESSIONNAME -ne "Console") {
                    Write-Log "Patch My PC is running in SYSTEM session: Only some updates may apply (Store/user apps may be skipped)." "WARN" -PreBreak
                }
                Write-Log "Running Patch My PC Home Updater silently..." "NOTIFY"
                $patchMyPCLog = "$logDir\$(get-date -f 'yyyy-MM-dd.HHmmss')-PatchMyPCUpdate.log"
                $patchMyPCLogErr = "$logDir\$(get-date -f 'yyyy-MM-dd.HHmmss')-PatchMyPCUpdate-err.log"
                if ($patchInfo.AliasAvailable) {
                    $process = Start-Process -FilePath 'patch-my-pc' -ArgumentList '/s' -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $patchMyPCLog -RedirectStandardError $patchMyPCLogErr
                }
                elseif ($patchInfo.Path) {
                    $process = Start-Process -FilePath $patchInfo.Path -ArgumentList '/s' -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $patchMyPCLog -RedirectStandardError $patchMyPCLogErr
                }
                else {
                    throw "Patch My PC executable not found."
                }
                if (Test-Path $patchMyPCLogErr) {
                    $patchMyPCErr = Get-Content $patchMyPCLogErr -Raw
                    if ($patchMyPCErr) {
                        Write-Log "Patch My PC error output:`n$patchMyPCErr" "ERROR"
                    }
                    Add-ToolLogToMainLog -ToolLogPath $patchMyPCLogErr -MainLogPath $logFile -Header "Patch My PC ERROR"
                }
                if ($process.ExitCode -eq 0) {
                    Write-Log "Patch My PC update completed successfully." "SUCCESS" -PreBreak -PostBreak
                }
                else {
                    Write-Log ("Patch My PC updater exited with code " + $process.ExitCode) "ERROR" -PreBreak -PostBreak
                    Add-ToolLogToMainLog -ToolLogPath $patchMyPCLog -MainLogPath $logFile -Header "Patch My PC"
                }
                # --- Begin PatchMyPC log cleanup ---
                foreach ($tempLog in @($patchMyPCLog, $patchMyPCLogErr)) {
                    try {
                        if (Test-Path $tempLog) {
                            Remove-Item $tempLog -Force -ErrorAction Stop
                            Write-Log "Deleted Patch My PC temp log file: $tempLog" "INFO" -PostBreak
                        }
                    }
                    catch {
                        $err = $_
                        Write-Log ("Failed to delete Patch My PC temp log file ${tempLog}: " + $err.Exception.Message) "WARN" -PostBreak
                    }
                }
                # --- End PatchMyPC log cleanup ---
            }
            catch {
                $err = $_
                Write-Log ("Failed to run Patch My PC updater: " + $err.Exception.Message) "ERROR" -PreBreak -PostBreak
                Write-Log ("Full error details:`n" + ($err | Out-String)) "ERROR"
            }
        }
        else {
            Write-Log "Patch My PC updater not found or not installed. Skipping." "WARN" -PreBreak -PostBreak
        }
    }
    else {
        Write-Log "Skipping Patch My PC Update as per configuration." "INFO"
    }
}

# NOTE: Core Functions - Set-GlobalsFromConfig
function Set-GlobalsFromConfig($config) {
    $script:logDir = Test-LogDirAndFile ($config.logDir.Trim())
    $script:DaysToKeep = $config.DaysToKeep
    $script:ArchiveRetentionDays = $config.ArchiveRetentionDays
    $script:ShowLevelOnScreen = $config.ShowLevelOnScreen
    $script:ShowTimestampOnScreenentry = $config.ShowTimestampOnScreenentry
    $script:TimeoutSeconds = $config.TimeoutSeconds
    $script:waitSeconds = $script:TimeoutSeconds
    $script:UpdateTypes = $config.UpdateTypes
    $script:wingetSkipList = $config.wingetSkipList
    $script:logFile = Join-Path $script:logDir ("UpdateScript-" + (get-date -f 'yyyy-MM-dd.HHmmss') + ".log")
    $script:logfileMicrosoftStore = (get-date -f 'yyyy-MM-dd.HHmmss') + "-MicrosoftStoreUpdate.log"
    $script:logFileWindowsUpdate = (get-date -f 'yyyy-MM-dd.HHmmss') + "-WindowsUpdate.log"
}

# NOTE: Load Config and Set Globals
# =====================
# LOAD CONFIG AND SET GLOBALS (JSON-based)
# =====================
$config = Get-Config
Set-GlobalsFromConfig $config

# --- Auto-elevate if not running as admin (interactive session only) ---
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

# NOTE: Main Menu
# =====================
# MAIN MENU FOR INTERACTIVE SESSIONS
# =====================

# NOTE: Main Menu - Show-MainMenu
function Show-MainMenu {
    while ($true) {
        Write-Log "==== Windows Update Automation Main Menu ====" "HEADER" -SuppressLogFile
        Write-Log "1. Run updates now" "INFO" -SuppressLogFile
        Write-Log "2. View/Edit configuration" "INFO" -SuppressLogFile
        Write-Log "3. Exit" "INFO" -SuppressLogFile
        $choice = Read-Host "Select an option (1-3)"
        switch ($choice) {
            '1' { Run-AllUpdates }
            '2' { Show-ConfigMenu }
            '3' { return }
            default { Write-Log "Invalid selection. Please enter 1, 2, or 3." "WARN" -SuppressLogFile }
        }
    }
}

# NOTE: Main Menu - Show-ConfigMenu
function Show-ConfigMenu {
    $config = Get-Config
    Set-GlobalsFromConfig $config
    Write-Log "==== Current Configuration ====" "HEADER" -SuppressLogFile
    Write-Log ($config | ConvertTo-Json -Depth 5) "INFO" -SuppressLogFile
    Write-Log "Would you like to edit the config (E), re-run first-time setup (S), or exit (X)? (E/S/X)" "ASK" -SuppressLogFile
    $edit = Read-Host "Edit config (E), Setup (S), or Exit (X)?"
    if ($edit -match '^(E|e)') {
        notepad $jsonConfigPath
        Write-Log "Press Enter when done editing to reload config..." "ASK" -SuppressLogFile
        [void][System.Console]::ReadLine()
        $config = Get-Config
        Set-GlobalsFromConfig $config
        Write-Log "Config reloaded after edit." "SUCCESS"
    }
    elseif ($edit -match '^(S|s)') {
        $currentConfig = $config
        function PromptOrDefault($prompt, $current, $default) {
            $msg = "$prompt [current: $current, default: $default]"
            $input = Read-Host $msg
            if ($input) { $input } elseif ($current) { $current } else { $default }
        }
        $config = Start-FirstTimeSetup
        Set-GlobalsFromConfig $config
    }
    # After viewing/editing, return to main menu
}

# NOTE: First-time setup
# =====================
# FIRST-TIME SETUP LOGIC
# =====================

# NOTE: First-time setup - Start-FirstTimeSetup
function Start-FirstTimeSetup {
    Write-Log "Starting first-time setup for Windows Update Automation Script." "HEADER" -PreBreak
    # 1. Create an empty config hashtable with all needed keys
    $config = @{
        logDir                     = $null
        DaysToKeep                 = $null
        ArchiveRetentionDays       = $null
        ShowLevelOnScreen          = $null
        ShowTimestampOnScreenentry = $null
        TimeoutSeconds             = $null
        UpdateTypes                = @()
        wingetSkipList             = @()
        ScheduledTask              = @{
            Enabled   = $null
            Frequency = $null
            Time      = $null
            DayOfWeek = $null
        }
    }

    # NOTE: First-time setup - Prompt user for values
    # 2. Ask user for each value
    $defaultLogDir = $defaultConfig.logDir
    $logDirInput = Read-Host ("Log directory [default: $defaultLogDir]")
    $defaultDaysToKeep = $defaultConfig.DaysToKeep
    $daysToKeepInput = Read-Host ("Number of days to keep logs before archiving [default: $defaultDaysToKeep]")
    $defaultArchiveRetention = $defaultConfig.ArchiveRetentionDays
    $archiveRetentionInput = Read-Host ("Number of days to keep archived logs [default: $defaultArchiveRetention]")
    $defaultShowLevel = $defaultConfig.ShowLevelOnScreen
    $showLevelInput = Read-Host ("Show log level on screen? (Y/N) [default: $defaultShowLevel]")
    $defaultShowTimestamp = $defaultConfig.ShowTimestampOnScreenentry
    $showTimestampInput = Read-Host ("Show timestamp on screen? (Y/N) [default: $defaultShowTimestamp]")
    $defaultTimeout = $defaultConfig.TimeoutSeconds
    $timeoutInput = Read-Host ("Timeout (seconds) for file unlock waits [default: $defaultTimeout]")
    $defaultUpdateTypes = $defaultConfig.UpdateTypes -join ', '
    $updateTypesInput = Read-Host ("Update types to enable (comma separated: Windows, Office, Winget, PatchMyPC) [default: $defaultUpdateTypes]")
    $defaultSkipList = $defaultConfig.wingetSkipList
    # NOTE: First-time setup - Prompt user for winget skip list
    # --- Begin interactive winget skip list management ---
    $currentSkipList = @($defaultSkipList)
    Write-Log ("Current winget skip list: " + ($currentSkipList -join ', ')) "INFO"
    $manageSkipList = $true
    while ($manageSkipList) {
        Write-Log "Winget Skip List Management:" "HEADER"
        Write-Log ("Current skip list: " + ($currentSkipList -join ', ')) "INFO"
        Write-Log "Options: [A]dd, [R]emove, [D]one" "ASK"
        $action = Read-Host "Choose action (A/R/D)"
        switch ($action.ToUpper()) {
            'A' {
                $toAdd = Read-Host "Enter app name or ID to add to skip list (or blank to cancel)"
                if ($toAdd) {
                    Write-Log "Searching winget for '$toAdd'..." "INFO"
                    try {
                        $searchResults = winget search --id "$toAdd" --name "$toAdd" | Select-String -Pattern "^(.*?)\s{2,}(.*?)\s{2,}(.*?)$" | ForEach-Object {
                            $fields = $_.Line -split "\s{2,}"
                            if ($fields.Count -ge 3) {
                                [PSCustomObject]@{
                                    Name    = $fields[0].Trim()
                                    Id      = $fields[1].Trim()
                                    Version = $fields[2].Trim()
                                }
                            }
                        }
                        if (-not $searchResults -or $searchResults.Count -eq 0) {
                            Write-Log "No results found for '$toAdd'. Please check the name or ID." "WARN"
                        }
                        elseif ($searchResults.Count -eq 1) {
                            $result = $searchResults[0]
                            if ($currentSkipList -contains $result.Id -or $currentSkipList -contains $result.Name) {
                                Write-Log "'$($result.Name)' is already in the skip list." "INFO"
                            }
                            else {
                                $currentSkipList += $result.Id
                                Write-Log "Added '$($result.Name)' (ID: $($result.Id)) to skip list." "SUCCESS"
                            }
                        }
                        else {
                            Write-Log "Multiple results found:" "INFO"
                            $i = 1
                            foreach ($res in $searchResults) {
                                Write-Log ("[$i] $($res.Name) (ID: $($res.Id))") "INFO"
                                $i++
                            }
                            $sel = Read-Host "Enter number(s) to add (comma separated), or blank to cancel"
                            if ($sel) {
                                $indices = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
                                foreach ($idx in $indices) {
                                    $idxNum = [int]$idx
                                    if ($idxNum -ge 1 -and $idxNum -le $searchResults.Count) {
                                        $chosen = $searchResults[$idxNum - 1]
                                        if ($currentSkipList -contains $chosen.Id -or $currentSkipList -contains $chosen.Name) {
                                            Write-Log "'$($chosen.Name)' is already in the skip list." "INFO"
                                        }
                                        else {
                                            $currentSkipList += $chosen.Id
                                            Write-Log "Added '$($chosen.Name)' (ID: $($chosen.Id)) to skip list." "SUCCESS"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        $err = $_
                        Write-Log ("Error searching winget: " + $err.Exception.Message) "ERROR"
                    }
                }
            }
            'R' {
                if ($currentSkipList.Count -eq 0) {
                    Write-Log "Skip list is empty." "INFO"
                }
                else {
                    $i = 1
                    foreach ($item in $currentSkipList) {
                        Write-Log ("[$i] $item") "INFO"
                        $i++
                    }
                    $sel = Read-Host "Enter number(s) to remove (comma separated), or blank to cancel"
                    if ($sel) {
                        $indices = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
                        $toRemove = @()
                        foreach ($idx in $indices) {
                            $idxNum = [int]$idx
                            if ($idxNum -ge 1 -and $idxNum -le $currentSkipList.Count) {
                                $toRemove += $currentSkipList[$idxNum - 1]
                            }
                        }
                        $currentSkipList = $currentSkipList | Where-Object { $toRemove -notcontains $_ }
                        Write-Log ("Removed: " + ($toRemove -join ', ')) "SUCCESS"
                    }
                }
            }
            'D' { $manageSkipList = $false }
            default { Write-Log "Invalid selection. Please enter A, R, or D." "WARN" }
        }
    }
    $config.wingetSkipList = $currentSkipList
    # --- End interactive winget skip list management ---
    # NOTE: First-time setup - Prompt user for scheduled task/frequency
    # --- Begin improved scheduled task/frequency prompts ---
    $defaultSched = $defaultConfig.ScheduledTask
    $enableSchedInput = Read-Host ("Enable scheduled task? (Y/N) [default: $($defaultSched.Enabled)]")
    $schedEnabled = if ($enableSchedInput -match '^(Y|y)') { $true } elseif ($enableSchedInput -match '^(N|n)') { $false } else { $defaultSched.Enabled }
    $schedFrequency = $defaultSched.Frequency
    $schedTime = $defaultSched.Time
    $schedDayOfWeek = $defaultSched.DayOfWeek
    $schedDayOfMonth = $null
    $schedNthWeek = $null
    $schedNthWeekday = $null
    if ($schedEnabled) {
        $validFrequencies = @('Daily', 'Weekly', 'Monthly')
        do {
            $freqInput = Read-Host ("Schedule frequency (Daily, Weekly, Monthly) [D/W/M, default: $($defaultSched.Frequency)]")
            if ($freqInput) {
                $schedFrequency = Normalize-Frequency $freqInput
            }
            else {
                $schedFrequency = $defaultSched.Frequency
            }
            if ($validFrequencies -notcontains $schedFrequency) {
                Write-Log "Invalid schedule frequency. Please enter D, W, M, Daily, Weekly, or Monthly." "WARN"
            }
        } while ($validFrequencies -notcontains $schedFrequency)
        # --- Time prompt ---
        $timeInput = Read-Host ("Schedule time (HH:mm, HHmm, H, H:MM, 12hr/24hr, am/pm allowed) [default: $($defaultSched.Time)]")
        if ($timeInput) {
            $schedTime = Normalize-TimeString -InputTime $timeInput -DefaultTime $defaultSched.Time
        }
        else {
            $schedTime = $defaultSched.Time
        }
        # --- Day prompt ---
        if ($schedFrequency -eq 'Daily') {
            $dayInput = Read-Host ("Day to run (e.g. Mon, Tuesday, leave blank for every day)")
            $schedDayOfWeek = if ($dayInput) { Normalize-DayOfWeek -InputDay $dayInput } else { $null }
        }
        elseif ($schedFrequency -eq 'Weekly') {
            $dowInput = Read-Host ("Day of week for schedule (e.g. Sun, Monday) [default: $($defaultSched.DayOfWeek)]")
            $schedDayOfWeek = if ($dowInput) { Normalize-DayOfWeek -InputDay $dowInput } else { $defaultSched.DayOfWeek }
            while (-not $schedDayOfWeek) {
                $dowInput = Read-Host ("Please enter a valid day of week (e.g. Mon, Tue, Wednesday)")
                $schedDayOfWeek = Normalize-DayOfWeek -InputDay $dowInput
            }
        }
        elseif ($schedFrequency -eq 'Monthly') {
            $monthlyType = Read-Host ("Monthly schedule: Enter 'date' for day of month (e.g. 15), or 'weekday' for Nth weekday (e.g. 2nd Tuesday)")
            if ($monthlyType -match '^(date|d)$') {
                $domInput = Read-Host ("Day of month to run (1-31)")
                if ($domInput -match '^(\\d{1,2})$' -and [int]$domInput -ge 1 -and [int]$domInput -le 31) {
                    $schedDayOfMonth = [int]$domInput
                }
            }
            elseif ($monthlyType -match '^(weekday|w)$') {
                $nthInput = Read-Host ("Which week? (1st, 2nd, 3rd, 4th, last)")
                $weekdayInput = Read-Host ("Day of week (e.g. Mon, Tuesday)")
                $schedNthWeek = $nthInput
                $schedNthWeekday = Normalize-DayOfWeek $weekdayInput
            }
        }
    }
    # --- End improved scheduled task/frequency prompts ---

    # NOTE: First-time setup - Assign answers to config
    # 3. Assign answers to config
    $config.logDir = if ($logDirInput) { $logDirInput } else { $defaultLogDir }
    $config.DaysToKeep = if ($daysToKeepInput -as [int]) { [int]$daysToKeepInput } else { $defaultDaysToKeep }
    $config.ArchiveRetentionDays = if ($archiveRetentionInput -as [int]) { [int]$archiveRetentionInput } else { $defaultArchiveRetention }
    $config.ShowLevelOnScreen = if ($showLevelInput -match '^(Y|y)') { $true } elseif ($showLevelInput -match '^(N|n)') { $false } else { $defaultShowLevel }
    $config.ShowTimestampOnScreenentry = if ($showTimestampInput -match '^(Y|y)') { $true } elseif ($showTimestampInput -match '^(N|n)') { $false } else { $defaultShowTimestamp }
    $config.TimeoutSeconds = if ($timeoutInput -as [int]) { [int]$timeoutInput } else { $defaultTimeout }
    $config.UpdateTypes = if ($updateTypesInput) {
        $updateTypesInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    else {
        $defaultConfig.UpdateTypes
    }
    $config.wingetSkipList = $currentSkipList
    $config.ScheduledTask = @{
        Enabled    = $schedEnabled
        Frequency  = $schedFrequency
        Time       = $schedTime
        DayOfWeek  = $schedDayOfWeek
        DayOfMonth = $schedDayOfMonth
        NthWeek    = $schedNthWeek
        NthWeekday = $schedNthWeekday
    }
    # --- End config assignment ---

    # NOTE: First-time setup - Check for and install PatchMyPC
    # Patch My PC presence check and install prompt
    $patchInfo = Get-PatchMyPCInfo
    if (-not $patchInfo.Installed) {
        Write-Log "Patch My PC is not installed. Would you like to install it now? (Y/N)" "ASK"
        $installPatch = Read-Host "Install Patch My PC? (Y/N)"
        if ($installPatch -match '^(Y|y)') {
            try {
                Write-Log "Installing Patch My PC using winget..." "NOTIFY"
                winget install --id=PatchMyPC.PatchMyPC -e
                $patchInfo = Get-PatchMyPCInfo
                if ($patchInfo.Installed) {
                    Write-Log "Patch My PC installed successfully." "SUCCESS"
                }
                else {
                    Write-Log "Patch My PC installation did not complete successfully. It will be excluded from update types." "WARN"
                    $config.UpdateTypes = $config.UpdateTypes | Where-Object { $_ -ne 'PatchMyPC' }
                }
            }
            catch {
                $err = $_
                Write-Log ("Failed to install Patch My PC: " + $err.Exception.Message) "ERROR"
                $config.UpdateTypes = $config.UpdateTypes | Where-Object { $_ -ne 'PatchMyPC' }
            }
        }
        else {
            Write-Log "Patch My PC will be excluded from update types." "INFO"
            $config.UpdateTypes = $config.UpdateTypes | Where-Object { $_ -ne 'PatchMyPC' }
        }
    }

    # NOTE: First-time setup - Save config to JSON
    Save-Config $config
    if ($schedEnabled) { Register-WindowsUpdateScheduledTask -Config $config }
    Write-Log "First-time setup complete. Config saved to $jsonConfigPath" "SUCCESS" -PostBreak
    return $config
}

# NOTE: Interactive Session Main Menu Entry Point
# =====================
# INTERACTIVE SESSION MAIN MENU ENTRY POINT
# =====================
if ((-not (Test-Path $jsonConfigPath)) -or ((Test-Path $oldConfigPath) -and -not (Test-Path $jsonConfigPath))) {
    # If config is missing or only old config exists, run first-time setup
    $config = Start-FirstTimeSetup
    Set-GlobalsFromConfig $config
}

# NOTE: On load action based on how script is run
if ($forceShowMenu -or ([System.Diagnostics.Process]::GetCurrentProcess().SessionId -ne 0 -and $env:SESSIONNAME -eq "Console")) {
    $menuAction = Show-MainMenu
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
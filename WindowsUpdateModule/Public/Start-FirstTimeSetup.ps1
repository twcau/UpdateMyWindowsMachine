function Start-FirstTimeSetup {
    <#
    .SYNOPSIS
        Interactive first-time setup for Windows Update Automation Script.
    .DESCRIPTION
        Prompts the user for all configuration options, validates input, and saves the config.
    .OUTPUTS
        [hashtable] The saved config object, or $null on error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$JsonConfigPath,
        [Parameter(Mandatory = $false)]
        [string]$OldConfigPath,
        [Parameter(Mandatory = $false)]
        [hashtable]$DefaultConfig
    )
    Write-Log "Starting first-time setup for Windows Update Automation Script." "HEADER" -PreBreak
    # 1. Load current config if it exists, else use defaults
    $config = $null
    if (Test-Path $JsonConfigPath) {
        try {
            $config = Get-Config -JsonConfigPath $JsonConfigPath -OldConfigPath $OldConfigPath -DefaultConfig $defaultConfig
        }
        catch {
            Write-ErrorLog -Message "Failed to load config, using defaults." -Exception $_
            $config = $defaultConfig
        }
    }
    else {
        $config = $defaultConfig
    }
    # Defensive: Validate and repair config before prompting
    $defaultConfig = Get-DefaultConfig
    $config = Repair-Config -Config $config -DefaultConfig $defaultConfig
    # Prompt logic: show current value if exists, else show hard default
    $config.LogDir = Invoke-PromptOrDefault -Prompt "Log directory" -Current $config.LogDir -HardDefault $defaultConfig.LogDir
    $config.DaysToKeep = [int](Invoke-PromptOrDefault -Prompt "Number of days to keep logs before archiving" -Current $config.DaysToKeep -HardDefault $defaultConfig.DaysToKeep)
    $config.ArchiveRetentionDays = [int](Invoke-PromptOrDefault -Prompt "Number of days to keep archived logs" -Current $config.ArchiveRetentionDays -HardDefault $defaultConfig.ArchiveRetentionDays)
    $config.ShowLevelOnScreen = (Invoke-PromptOrDefault -Prompt "Show log level on screen? (Y/N)" -Current (ConvertTo-YNString $config.ShowLevelOnScreen) -HardDefault (ConvertTo-YNString $defaultConfig.ShowLevelOnScreen)) -match '^(Y|y|True)$'
    $config.ShowTimestampOnScreen = (Invoke-PromptOrDefault -Prompt "Show timestamp on screen? (Y/N)" -Current (ConvertTo-YNString $config.ShowTimestampOnScreen) -HardDefault (ConvertTo-YNString $defaultConfig.ShowTimestampOnScreen)) -match '^(Y|y|True)$'
    $config.TimeoutSeconds = [int](Invoke-PromptOrDefault -Prompt "Timeout (seconds) for file unlock waits" -Current $config.TimeoutSeconds -HardDefault $defaultConfig.TimeoutSeconds)
    $updateTypesDefault = ($config.UpdateTypes -join ', ')
    if (-not $updateTypesDefault) { $updateTypesDefault = $defaultConfig.UpdateTypes -join ', ' }
    $updateTypesInput = Read-HostIfInteractive ("Update types to enable (comma separated: Windows, Office, Winget, PatchMyPC) [default: $updateTypesDefault]")
    $config.UpdateTypes = if ($updateTypesInput) {
        $updateTypesInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    else {
        $updateTypesDefault -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    # Winget skip list management
    $currentSkipList = @($config.wingetSkipList)
    Write-Log ("Current winget skip list: " + ($currentSkipList -join ', ')) "INFO"
    $manageSkipList = $true
    while ($manageSkipList) {
        Write-Log "Winget Skip List Management:" "HEADER"
        Write-Log ("Current skip list: " + ($currentSkipList -join ', ')) "INFO"
        Write-Log "Options: [A]dd, [R]emove, [D]one" "ASK"
    $action = Read-HostIfInteractive "Choose action (A/R/D)"
        switch ($action.ToUpper()) {
            'A' {
                $toAdd = Read-HostIfInteractive "Enter app name or ID to add to skip list (or blank to cancel)"
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
                            $sel = Read-HostIfInteractive "Enter number(s) to add (comma separated), or blank to cancel"
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
                        Write-ErrorLog -Message "Error searching winget" -Exception $_
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
                    $sel = Read-HostIfInteractive "Enter number(s) to remove (comma separated), or blank to cancel"
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
    # Scheduled task setup
    $sched = $config.ScheduledTask
    $schedEnabled = (Invoke-PromptOrDefault -Prompt "Enable scheduled task? (Y/N)" -Current $sched.Enabled -HardDefault $defaultConfig.ScheduledTask.Enabled) -match '^(Y|y|True)$'
    # Normalize frequency input
    $schedFrequencyRaw = Invoke-PromptOrDefault -Prompt "Schedule frequency (Daily, Weekly, Monthly) [D/W/M]" -Current $sched.Frequency -HardDefault $defaultConfig.ScheduledTask.Frequency
    switch ($schedFrequencyRaw.ToUpper()) {
        'D' { $schedFrequency = 'Daily' }
        'DAILY' { $schedFrequency = 'Daily' }
        'W' { $schedFrequency = 'Weekly' }
        'WEEKLY' { $schedFrequency = 'Weekly' }
        'M' { $schedFrequency = 'Monthly' }
        'MONTHLY' { $schedFrequency = 'Monthly' }
        default {
            Write-Log "Unknown schedule frequency: $schedFrequencyRaw" "WARN"
            $schedFrequency = $defaultConfig.ScheduledTask.Frequency
        }
    }
    $schedTimeRaw = Invoke-PromptOrDefault -Prompt "Schedule time (HH:mm, HHmm, H, H:MM, 12hr/24hr, am/pm allowed)" -Current $sched.Time -HardDefault $defaultConfig.ScheduledTask.Time
    $schedTime = Format-TimeString $schedTimeRaw
    $schedDayOfWeek = $null
    $schedDayOfMonth = $sched.DayOfMonth
    $schedNthWeek = $sched.NthWeek
    $schedNthWeekday = $sched.NthWeekday
    if ($schedFrequency -eq 'Weekly') {
        $validDays = @('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')
        $abbrDays = @{'sun' = 'Sunday'; 'mon' = 'Monday'; 'tue' = 'Tuesday'; 'wed' = 'Wednesday'; 'thu' = 'Thursday'; 'fri' = 'Friday'; 'sat' = 'Saturday' }
        while ($true) {
            $inputDay = Invoke-PromptOrDefault -Prompt "Day of week for schedule (e.g. Sun, Monday)" -Current $sched.DayOfWeek -HardDefault $defaultConfig.ScheduledTask.DayOfWeek
            if (-not $inputDay) { Write-Log "Please enter a value." "WARN"; continue }
            $inputDay = $inputDay.ToString().Trim().ToLower()
            if ($inputDay.Length -eq 1) {
                Write-Log "Single-letter days are not accepted. Please enter a full day name (e.g. Sunday) or 3-letter abbreviation (e.g. Sun)." "WARN"
                continue
            }
            if ($validDays | ForEach-Object { $_.ToLower() } | Where-Object { $_ -eq $inputDay }) {
                $schedDayOfWeek = ($validDays | Where-Object { $_.ToLower() -eq $inputDay })[0]; break
            }
            elseif ($abbrDays.ContainsKey($inputDay)) {
                $schedDayOfWeek = $abbrDays[$inputDay]; break
            }
            else {
                Write-Log "Invalid day of week. Please enter a full day name (e.g. Sunday) or 3-letter abbreviation (e.g. Sun)." "WARN"
            }
        }
        # Defensive: ensure only valid day name is set
        if (-not $validDays -contains $schedDayOfWeek) {
            Write-Log "Internal error: Invalid day of week selected. Aborting scheduled task setup." "ERROR"
            $schedDayOfWeek = $null
        }
    }
    elseif ($schedFrequency -eq 'Monthly') {
    $monthlyType = Read-HostIfInteractive ("Monthly schedule: Enter 'date' for day of month (e.g. 15), or 'weekday' for Nth weekday (e.g. 2nd Tuesday)")
        if ($monthlyType -match '^(date|d)$') {
            $domInput = Read-HostIfInteractive ("Day of month to run (1-31)")
            if ($domInput -match '^(\\d{1,2})$' -and [int]$domInput -ge 1 -and [int]$domInput -le 31) {
                $schedDayOfMonth = [int]$domInput
            }
        }
        elseif ($monthlyType -match '^(weekday|w)$') {
            $nthInput = Read-HostIfInteractive ("Which week? (1st, 2nd, 3rd, 4th, last)")
            $weekdayInput = Read-HostIfInteractive ("Day of week (e.g. Mon, Tuesday)")
            $schedNthWeek = $nthInput
            $schedNthWeekday = Format-DayOfWeek $weekdayInput
        }
    }
    $config.ScheduledTask = @{
        Enabled    = $schedEnabled
        Frequency  = $schedFrequency
        Time       = $schedTime
        DayOfWeek  = $schedDayOfWeek
        DayOfMonth = $schedDayOfMonth
        NthWeek    = $schedNthWeek
        NthWeekday = $schedNthWeekday
    }
    $patchInfo = Get-PatchMyPCInfo
    if (-not $patchInfo.Installed) {
        Write-Log "Patch My PC is not installed. Would you like to install it now? (Y/N)" "ASK"
    $installPatch = Read-HostIfInteractive "Install Patch My PC? (Y/N)"
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
                Write-ErrorLog -Message "Failed to install Patch My PC" -Exception $_
                $config.UpdateTypes = $config.UpdateTypes | Where-Object { $_ -ne 'PatchMyPC' }
            }
        }
        else {
            Write-Log "Patch My PC will be excluded from update types." "INFO"
            $config.UpdateTypes = $config.UpdateTypes | Where-Object { $_ -ne 'PatchMyPC' }
        }
    }
    Show-SettingsSummary -Config $config
    Save-Config -Config $config -JsonConfigPath $JsonConfigPath
    # Defensive: ensure $config is a hashtable after loading
    if ($config -is [System.Object[]]) {
        $config = $config | Where-Object { $_ -is [System.Collections.Hashtable] } | Select-Object -First 1
    }
    if ($config -is [System.Collections.Hashtable]) {
        if ($schedEnabled -and $schedDayOfWeek) {
            Register-WindowsUpdateScheduledTask -Config $config -TaskName 'UpdateMyWindowsMachine'
        }
        elseif ($schedEnabled) {
            Write-Log "Scheduled task not created due to invalid day of week." "ERROR"
        }
        Write-Log "First-time setup complete. Config saved to $JsonConfigPath" "SUCCESS" -PostBreak
        return $config
    }
    else {
        Write-ErrorLog -Message "Internal error: Config is not a hashtable. Aborting."
        return $null
    }
}

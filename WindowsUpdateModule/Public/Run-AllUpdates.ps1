function Run-AllUpdates {
    [CmdletBinding()]
    param()
    # Windows Update
    if ($UpdateTypes -contains 'Windows') {
        if (-not (Test-IsElevated)) {
            Write-Log "Windows Update requires administrative privileges. Please run this script as Administrator to perform Windows Update." "ERROR" -PreBreak -PostBreak
        }
        else {
            Write-Log "Commencing Windows Update process..." "NOTIFY" -PreBreak
            try {
                Get-WindowsUpdate -AcceptAll -Install -AutoReboot | Tee-Object "$logDir\$LogFileWindowsUpdate"
                Add-LogToMainLog -ToolLogPath "$logDir\$LogFileWindowsUpdate" -MainLogPath $logFile -Header "Windows Update"
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
                    Add-LogToMainLog -ToolLogPath $patchMyPCLogErr -MainLogPath $logFile -Header "Patch My PC ERROR"
                }
                if ($process.ExitCode -eq 0) {
                    Write-Log "Patch My PC update completed successfully." "SUCCESS" -PreBreak -PostBreak
                }
                else {
                    Write-Log ("Patch My PC updater exited with code " + $process.ExitCode) "ERROR" -PreBreak -PostBreak
                    Add-LogToMainLog -ToolLogPath $patchMyPCLog -MainLogPath $logFile -Header "Patch My PC"
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

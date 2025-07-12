function Register-WindowsUpdateScheduledTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [string]$TaskName = "UpdateMyWindowsMachine"
    )
    $taskName = $TaskName
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
        $trigger = New-ScheduledTaskTrigger -Daily -At $time
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

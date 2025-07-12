function Format-DayOfWeek {
    [CmdletBinding()]
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
    $inputDayTrimmed = $InputDay.Trim()
    if ($days.ContainsKey($inputDayTrimmed)) { return $days[$inputDayTrimmed] }
    $inputDayFormatted = $inputDayTrimmed.Substring(0, 1).ToUpper() + $inputDayTrimmed.Substring(1).ToLower()
    if ($days.Values -contains $inputDayFormatted) { return $inputDayFormatted }
    return $null
}

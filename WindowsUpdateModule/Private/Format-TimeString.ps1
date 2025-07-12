function Format-TimeString {
    [CmdletBinding()]
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
    return $DefaultTime
}

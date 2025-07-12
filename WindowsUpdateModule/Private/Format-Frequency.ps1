function Format-Frequency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputValue
    )
    if (-not $InputValue) { return $null }
    $val = $InputValue.Trim().ToLower()
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

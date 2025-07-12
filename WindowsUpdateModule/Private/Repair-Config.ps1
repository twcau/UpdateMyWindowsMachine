function Repair-Config {
    <#
    .SYNOPSIS
        Validates and repairs a config hashtable, ensuring all required keys and nested keys are present and non-null, using defaults as needed.
    .PARAMETER Config
        The config hashtable to validate/repair.
    .PARAMETER DefaultConfig
        The default config hashtable to use for missing/null values.
    .OUTPUTS
        [hashtable] The repaired config.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [hashtable]$DefaultConfig
    )
    $repaired = @{}
    foreach ($key in $DefaultConfig.Keys) {
        if ($Config.ContainsKey($key) -and $null -ne $Config[$key]) {
            if ($DefaultConfig[$key] -is [hashtable]) {
                $repaired[$key] = Repair-Config -Config $Config[$key] -DefaultConfig $DefaultConfig[$key]
            } else {
                $repaired[$key] = $Config[$key]
            }
        } else {
            $repaired[$key] = $DefaultConfig[$key]
        }
    }
    return $repaired
}

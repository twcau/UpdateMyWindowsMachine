function Save-Config {
    <#
    .SYNOPSIS
        Saves the configuration hashtable to a JSON file.
    .PARAMETER Config
        The configuration hashtable to save.
    .PARAMETER JsonConfigPath
        The path to the JSON config file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [string]$JsonConfigPath
    )
    $json = $Config | ConvertTo-Json -Depth 5
    Set-Content -Path $JsonConfigPath -Value $json -Encoding UTF8
}

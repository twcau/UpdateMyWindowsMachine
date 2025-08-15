function Get-Config {
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
    # Migrate from old psd1 if needed
    if (($OldConfigPath -and (Test-Path $OldConfigPath)) -and -not (Test-Path $JsonConfigPath)) {
        try {
            $psd1Config = Import-PowerShellDataFile $OldConfigPath
            $psd1Config | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonConfigPath -Encoding UTF8
            Remove-Item $OldConfigPath -Force
        }
        catch {
            Write-Log "Could not parse legacy .psd1 config. Using default config and recreating as JSON. If you had custom settings, please reconfigure via the menu." "WARN"
            Save-Config -Config $DefaultConfig -JsonConfigPath $JsonConfigPath
            return $DefaultConfig
        }
    }
    if (Test-Path $JsonConfigPath) {
        try {
            $config = Get-Content $JsonConfigPath -Raw | ConvertFrom-Json
            # Convert PSCustomObject to hashtable for mutability
            $config = $config | ConvertTo-Json -Depth 5 | ConvertFrom-Json -AsHashtable
            $defaultConfig = Get-DefaultConfig
            $config = Repair-Config -Config $config -DefaultConfig $defaultConfig
            return $config
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Log "Failed to load config file: $errMsg. Recreating with defaults." "WARN"
            # Backup the bad config file for diagnostics
            $backupPath = "$JsonConfigPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            try { Copy-Item $JsonConfigPath $backupPath -ErrorAction Stop } catch {}
            Save-Config -Config $DefaultConfig -JsonConfigPath $JsonConfigPath
            return $DefaultConfig
        }
    }
    else {
        Save-Config -Config $DefaultConfig -JsonConfigPath $JsonConfigPath
        return $DefaultConfig
    }
}

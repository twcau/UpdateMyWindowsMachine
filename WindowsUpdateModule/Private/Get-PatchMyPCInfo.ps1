function Get-PatchMyPCInfo {
    [CmdletBinding()]
    param()
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

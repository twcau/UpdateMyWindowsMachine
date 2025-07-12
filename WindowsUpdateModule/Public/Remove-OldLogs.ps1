function Remove-OldLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogDir,
        [Parameter(Mandatory)]
        [int]$DaysToKeep
    )
    $now = Get-Date
    if (Test-Path $LogDir) {
        Get-ChildItem -Path $LogDir -File | Where-Object {
            $_.LastWriteTime -lt $now.AddDays(-$DaysToKeep)
        } | ForEach-Object {
            Remove-Item $_.FullName -Force
        }
    }
}

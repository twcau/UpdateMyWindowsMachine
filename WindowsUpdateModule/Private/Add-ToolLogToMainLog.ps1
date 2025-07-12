function Add-LogToMainLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ToolLogPath,
        [Parameter(Mandatory)]
        [string]$MainLogPath,
        [string]$Header
    )
    if (Test-Path $ToolLogPath) {
        if ($Header) {
            Add-Content -Path $MainLogPath -Value ("==== $Header ====")
        }
        Get-Content $ToolLogPath | Add-Content -Path $MainLogPath
    }
}

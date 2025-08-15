function Read-HostIfInteractive {
    <#
    .SYNOPSIS
        Wrapper for Read-Host that only prompts in interactive sessions.
    .DESCRIPTION
        If running interactively, prompts the user. If not, returns the provided default value and logs the skip.
    .PARAMETER Prompt
        The prompt string to display to the user.
    .PARAMETER Default
        The value to return if not interactive. Defaults to $null.
    .OUTPUTS
        [string] User input, or the default value if non-interactive.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        $Default = $null
    )
    # Robust, multi-fallback interactivity check
    $interactive = $false
    try {
        # 1. Try RawUI.KeyAvailable (works in most console hosts)
        $null = $Host.UI.RawUI.KeyAvailable
        $interactive = $true
    }
    catch {
        # 2. Check for common interactive host names
        if ($Host.Name -match 'ConsoleHost|pwsh' -or $Host.Name -eq 'Windows PowerShell ISE Host') {
            $interactive = $true
        }
        elseif ($env:SESSIONNAME -eq 'Console') {
            $interactive = $true
        }
        elseif ($PSVersionTable.PSEdition -eq 'Core' -and $Host.Name -eq 'Visual Studio Code Host') {
            $interactive = $true
        }
        elseif ($env:WT_SESSION) {
            # Windows Terminal
            $interactive = $true
        }
    }
    if (-not $interactive) {
        Write-Host "[DEBUG] Read-HostIfInteractive: Session not detected as interactive. Prompt '$Prompt' skipped. Host: $($Host.Name), SESSIONNAME: $env:SESSIONNAME, WT_SESSION: $env:WT_SESSION"
        # Fallback: if running in a visible console, force prompt
        if ($Host.Name -match 'ConsoleHost|pwsh' -or $env:SESSIONNAME -eq 'Console') {
            $interactive = $true
        }
    }
    if ($interactive) {
        return Read-Host $Prompt
    }
    else {
        if ($PSCmdlet -and (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            Write-Log ("Prompt '$Prompt' skipped (non-interactive session). Using default: $Default") 'INFO'
        }
        else {
            Write-Host "Prompt '$Prompt' skipped (non-interactive session). Using default: $Default"
        }
        return $Default
    }
}

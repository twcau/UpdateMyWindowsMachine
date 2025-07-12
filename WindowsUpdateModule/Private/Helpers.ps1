function Invoke-PromptOrDefault {
    <#
    .SYNOPSIS
        Prompts the user for input, showing a default value.
    .DESCRIPTION
        Centralized prompt logic for all scripts. Returns the user input or the default if blank.
    .PARAMETER Prompt
        The prompt string to display.
    .PARAMETER Current
        The current value to show as default.
    .PARAMETER HardDefault
        The hardcoded default value if current is null/empty.
    .OUTPUTS
        [string] The user input or the default value.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [Parameter(Mandatory)]
        $Current,
        [Parameter(Mandatory)]
        $HardDefault
    )
    $show = $Current
    if ($null -eq $show -or $show -eq "") { $show = $HardDefault }
    $userInput = Read-Host ("$Prompt [default: $show]")
    if ($userInput) { $userInput } else { $show }
}

function ConvertTo-YNString {
    <#
    .SYNOPSIS
        Converts a boolean to Y/N string.
    .PARAMETER Value
        The value to convert.
    .OUTPUTS
        [string] 'Y', 'N', or ''
    #>
    param(
        [Parameter(Mandatory)]
        $Value
    )
    if ($Value -eq $true) { return 'Y' }
    elseif ($Value -eq $false) { return 'N' }
    elseif ($null -eq $Value) { return '' }
    else { return $Value }
}

function Show-SettingsSummary {
    <#
    .SYNOPSIS
        Displays a summary of chosen settings before saving config.
    .PARAMETER Config
        The config object to summarize.
    #>
    param(
        [Parameter(Mandatory)]
        $Config
    )
    Write-Log "Summary of chosen settings:" "HEADER"
    foreach ($key in $Config.Keys) {
        Write-Log ($key + ': ' + $Config[$key]) "INFO"
    }
}

function Write-ErrorLog {
    <#
    .SYNOPSIS
        Centralized error handler. Logs and optionally throws or returns.
    .PARAMETER Message
        The error message.
    .PARAMETER Exception
        The exception object (optional).
    .PARAMETER Throw
        If set, rethrows the error after logging.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter()]
        $Exception,
        [switch]$Throw
    )
    if ($Exception) {
        Write-Log ($Message + ': ' + $Exception.Message) "ERROR"
    }
    else {
        Write-Log $Message "ERROR"
    }
    if ($Throw) { throw $Message }
}

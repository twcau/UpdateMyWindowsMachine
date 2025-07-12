<!-- vscode-markdown-toc -->
* [Overview](#Overview)
	* [Who is the audience of this script?](#Whoistheaudienceofthisscript)
* [Features](#Features)
* [Requirements](#Requirements)
* [Usage](#Usage)
* [Configuration](#Configuration)
* [Structure](#Structure)
* [Module Development](#ModuleDevelopment)
	* [Public Functions](#PublicFunctions)
	* [Private Helpers](#PrivateHelpers)
* [Credits](#Credits)
* [Like to say thank you?](#Liketosaythankyou)
* [References & Vendor Documentation](#ReferencesVendorDocumentation)
* [License](#License)

<!-- vscode-markdown-toc-config
	numbering=false
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc --># UpdateMyWindowsMachine

A modular, production-quality PowerShell solution for automating PowerShell commands to update Microsoft Windows, Microsoft Store, and Microsoft Office; along with some third-party updates (leveraging PatchMyPC). Includes robust configuration, logging, scheduling, and interactive menu support.



## <a name='Overview'></a>Overview

**Update My PC** is a comprehensive PowerShell automation script designed to keep your Windows system, Microsoft Store apps, Microsoft Office, and other applications up to date. It is intended to be run either interactively, or as a scheduled task via Windows Task Scheduler to provide a hands-off approach to regular system maintenance and patching.

### <a name='Whoistheaudienceofthisscript'></a>Who is the audience of this script?

This is primarily for a home/own PC use case, or where you have a very small office environment and the work you do/data you handle is of a very low security risk.

> [!CAUTION]
> Please use enterprise-grade methods of updating your Windows computers if you:
> - Are handling Sensitive PII,
> - Have serious audit responsibilities and accountablity around Information Security, such as ISO 27007/HIPAA/Sarbanes-Oxley Act (SOX)/PCI DSS/Graham-Leach-Bliley, etc.,
> - Need to actually meet your obligations under a Cybersecurity insurance policy your organisation holds,
> - Have other legal obligations that mean you can't afford to mess up, and/or
> - Any other reasons that warrant being properly serious about your enterprise computing environment.
> 
> If you or your organisation fall into any of these categories - then you should be looking at, budgeting for, and resourcing, proper solutions for maintaining your PC's updates, patching and security. This script is simply not intended for you.

## <a name='Features'></a>Features

- Modular PowerShell module (`WindowsUpdateModule`) with one function per file
- Interactive menu for manual operation
- **Updates your choice of supported software and components with a single script**
    - Configuration to choose which kinds or combination of top-level updates you want to run.
    - **Automated Windows Updates**: Checks for and installs all available Windows updates, including security and feature updates.
    - **Microsoft Store App Updates**: Updates Microsoft Store applications using `winget`.
    - **Microsoft Office Updates**: Detects and updates Microsoft Office installations, closing running Office apps as needed.
    - **Third-Party App Updates**: Optionally integrates with [Patch My PC Home Updater](https://patchmypc.com/home-updater) to update a wide range of third-party applications.
- **Configuration**
    - **Configurable Update Types**: Choose which update types to enable (Windows, Office, Winget, PatchMyPC), and any combination thereof, via a JSON config file or interactive menu.
    - **Winget Skip List**: Exclude specific apps from being updated by `winget` using a customizable skip list.
- **First-Time Setup Wizard**: Interactive setup for configuration, including scheduling, log management, and update preferences.
- **Robust Logging**: Logs all actions and results to a configurable directory, with retention and archiving options.
- **Scheduled Task Support**: Easily create or update a Windows Task Scheduler job to run the script automatically on a schedule (daily, weekly, or monthly).
- **Auto-Elevation**: Automatically relaunches itself with administrative privileges if required.
- **Error Handling**: Robust and graceful error handling, along with informative log messages for troubleshooting.
- Pester tests for functions

## <a name='Requirements'></a>Requirements
- PowerShell 5.1+
- Windows 10/11
- Administrative privileges for update operations
- [Patch My PC](https://patchmypc.com/home-updater) (optional, auto-installed if missing)

## <a name='Usage'></a>Usage
1. **Clone the repo**:
   ```powershell
   git clone <your-repo-url>
   cd UpdateMyWindowsMachine
   ```
2. **Run the entry script**:
   ```powershell
   .\WindowsUpdate.ps1
   ```
3. Use the first-time setup wizard, interactive menu, or configuration menu.

## <a name='Configuration'></a>Configuration

All settings are stored in `WindowsUpdateConfig.json`. Key options include:
- `logDir`: Directory for log files.
- `wingetSkipList`: List of app names or IDs to exclude from `winget` updates.
- `UpdateTypes`: Which update types to enable (`Windows`, `Office`, `Winget`, `PatchMyPC`).
- `ScheduledTask`: Scheduling options for automated runs.

You can edit this file manually, or use the script's interactive menu.

## <a name='Structure'></a>Structure
```
UpdateMyWindowsMachine/
├── README.md
├── WindowsUpdate.ps1                         # Entry point (loads module, runs menu/automation)
├── WindowsUpdateConfig.json                  # Main configuration file (auto-repaired if corrupted or incomplete)
├── WindowsUpdateModule/
│   ├── Private/                              # Private helpers (one per file, not exported)
│   │   ├── Add-LogToMainLog.ps1              # Appends tool-specific logs to the main log
│   │   ├── ConvertTo-YNString.ps1            # Converts boolean to Y/N string for prompts
│   │   ├── Format-DayOfWeek.ps1              # Input normalization helpers
│   │   ├── Format-Frequency.ps1
│   │   ├── Format-TimeString.ps1
│   │   ├── Get-DefaultConfig.ps1             # Provides bulletproof default config (all keys, nested included)
│   │   ├── Helpers.ps1                       # Centralized prompt, error, and summary logic
│   │   ├── Repair-Config.ps1                 # Validates/repairs config, auto-filling missing/null values
│   │   ├── Test-IsElevated.ps1               # Checks if running as administrator
│   │   ├── Test-LogDirectory.ps1             # Ensures log directory exists and is writable
│   │   └── Write-ErrorLog.ps1                # Writes error details to log
│   ├── Public/                               # Public functions (one per file, exported by the module)
│   │   ├── Get-Config.ps1                    # Loads and repairs config from disk
│   │   ├── Get-PatchMyPCInfo.ps1             # Gets Patch My PC installation info
│   │   ├── Register-WindowsUpdateScheduledTask.ps1 # Schedules/updates Windows Task Scheduler job
│   │   ├── Remove-OldLogs.ps1                # Deletes old log files based on retention policy
│   │   ├── Run-AllUpdates.ps1                # Orchestrates all update types (Windows, Office, Store, PatchMyPC)
│   │   ├── Save-Config.ps1                   # Saves config to disk
│   │   ├── Set-GlobalsFromConfig.ps1         # Sets global variables from config
│   │   ├── Show-ConfigMenu.ps1               # Config view/edit menu
│   │   ├── Show-MainMenu.ps1                 # Main interactive menu
│   │   ├── Start-FirstTimeSetup.ps1          # Interactive first-time setup wizard
│   ├── Tests/                                # Pester tests for all major functions
│   ├── WindowsUpdateModule.psd1              # Module manifest
│   ├── WindowsUpdateModule.psm1              # Module loader (dot-sources all Public/Private functions)
```
## <a name='ModuleDevelopment'></a>Module Development
- All functions are in `WindowsUpdateModule/Public` or `Private`.
- Add new features by creating new function files and updating the manifest if public.
- Run Pester tests in `WindowsUpdateModule/Tests` to validate changes.

### <a name='PublicFunctions'></a>Public Functions
- `Get-Config.ps1`: Loads and repairs config from disk. Migrates legacy config, auto-repairs missing/corrupt values, and returns a valid config hashtable.
- `Get-PatchMyPCInfo.ps1`: Gets Patch My PC installation info.
- `Register-WindowsUpdateScheduledTask.ps1`: Schedules or updates a Windows Task Scheduler job for automated runs, based on config.
- `Remove-OldLogs.ps1`: Deletes old log files from the log directory based on the retention policy in config.
- `Run-AllUpdates.ps1`: Orchestrates all update types (Windows, Office, Store/Winget, PatchMyPC) as configured, with robust error handling and logging.
- `Save-Config.ps1`: Saves the configuration hashtable to a JSON file.
- `Set-GlobalsFromConfig.ps1`: Sets global variables from the config for use throughout the module.
- `Show-ConfigMenu.ps1`: Displays and optionally edits the current configuration. Allows editing, re-running setup, or returning to main menu.
- `Show-MainMenu.ps1`: Displays the main interactive menu. Allows user to run updates, view/edit config, or exit.
- `Start-FirstTimeSetup.ps1`: Interactive first-time setup wizard. Prompts user for all configuration options, validates input, and saves the config.

### <a name='PrivateHelpers'></a>Private Helpers
- `Add-LogToMainLog.ps1`: Appends tool-specific logs to the main log.
- `ConvertTo-YNString.ps1`: Converts boolean to Y/N string for prompts.
- `Format-DayOfWeek.ps1`: Input normalization helpers.
- `Format-Frequency.ps1`: Input normalization helpers.
- `Format-TimeString.ps1`: Input normalization helpers.
- `Get-DefaultConfig.ps1`: Provides bulletproof default config (all keys, nested included).
- `Helpers.ps1`: Centralized prompt, error, and summary logic.
- `Invoke-PromptOrDefault.ps1`: Prompts user with default value logic.
- `Repair-Config.ps1`: Validates/repairs config, auto-filling missing/null values.
- `Test-IsElevated.ps1`: Checks if running as administrator.
- `Test-LogDirectory.ps1`: Ensures log directory exists and is writable.
- `Write-ErrorLog.ps1`: Writes error details to log.
- `Write-Log.ps1`: Logging implementation.

## <a name='Credits'></a>Credits

- Author: [Michael H (twcau)](https://github.com/twcau) ([License](https://github.com/twcau/UpdateMyWindowsMachine/blob/main/LICENSE))

## <a name='Liketosaythankyou'></a>Like to say thank you?

Feel welcome to:

[![Buy me a ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/H2H61HXBX1)

## <a name='ReferencesVendorDocumentation'></a>References & Vendor Documentation

- [Windows Update Command-Line Reference](https://www.itechtics.com/run-windows-update-cmd/#force-windows-update-check-using-run-command-box)
- [Enable Script Execution Policy in PowerShell](https://www.makeuseof.com/enable-script-execution-policy-windows-powershell/)
- [Microsoft Store App Updates](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [Patch My PC Documentation](https://patchmypc.com/home-updater)
- [Windows Package Manager (winget)](https://learn.microsoft.com/en-us/windows/package-manager/winget/)

## <a name='License'></a>License
See LICENSE file in the repo root.

---

**For detailed documentation, see function comments and the original script.**
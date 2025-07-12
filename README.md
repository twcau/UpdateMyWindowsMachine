# Update My PC - Microsoft Windows, Store, Office, and Other Application Updates Automation Script

<!-- vscode-markdown-toc -->
* [Overview](#Overview)
	* [Who is the audience of this script?](#Whoistheaudienceofthisscript)
* [Getting Started](#GettingStarted)
* [Features](#Features)
* [Configuration](#Configuration)
* [Requirements](#Requirements)
* [Credits](#Credits)
* [Like to say thank you?](#Liketosaythankyou)
* [References & Vendor Documentation](#ReferencesVendorDocumentation)
* [License](#License)

<!-- vscode-markdown-toc-config
	numbering=false
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->

## <a name='Overview'></a>Overview

**Update My PC** is a comprehensive PowerShell automation script designed to keep your Windows system, Microsoft Store apps, Microsoft Office, and other applications up to date. It is intended to be run interactively or scheduled via Windows Task Scheduler, providing a hands-off approach to system maintenance and patching.

### <a name='Whoistheaudienceofthisscript'></a>Who is the audience of this script?

This is primarily for a home/own PC use case, or where you have a very small office environment that is a low security risk.

> [!CAUTION]
> Please use enterprise-grade methods of updating your Windows computers if you:
> - Are handling Sensitive PII,
> - Have serious audit responsibilities and accountablity around Information Security, such as ISO 27007/HIPAA/Sarbanes-Oxley Act (SOX)/PCI DSS/Graham-Leach-Bliley, etc.,
> - Need to actually meet your obligations under a Cybersecurity insurance policy your organisation holds,
> - Have other legal obligations that mean you can't afford to mess up, and/or
> - Any other reasons that warrant being properly serious about your enterprise computing environment.

If you or your organisation fall into any of the above categories - then you should be looking at, budgeting for, and resourcing, proper solutions for maintaining your PC's updates, patching and security. This script is simply not intended for you.

## <a name='GettingStarted'></a>Getting Started

1. **Clone or Download** this repository to your local machine.
2. **Review and Edit Configuration**:
   - Run the script interactively to use the setup wizard (needed to create the `WindowsUpdateConfig.json` file), or edit `WindowsUpdateConfig.json` directly if you already have one.
3. **Run the Script interactively to configure**:
   - Right-click `WindowsUpdate.ps1` and select "Run with PowerShell" (as Administrator), or execute from a PowerShell terminal.
   - Use the interactive menu to run updates, edit configuration, or set up scheduled tasks.
   - When run interactively outside of an Administration terminal, you will be prompted via UAC to elevate your privledges
4. **Schedule Automatic Updates** (optional):
   - Use the script's first time setup, or configuration menu, to edit the config to enable and customise scheduled runs via Windows Task Scheduler.

## <a name='Features'></a>Features

- **Updates your choice of supported software and components with a single script**
    - Configuration to choose which kinds or combination of top-level updates you want to run.
    - **Automated Windows Updates**: Checks for and installs all available Windows updates, including security and feature updates.
    - **Microsoft Store App Updates**: Updates Microsoft Store applications using `winget`.
    - **Microsoft Office Updates**: Detects and updates Microsoft Office installations, closing running Office apps as needed.
    - **Third-Party App Updates**: Integrates with [Patch My PC Home Updater](https://patchmypc.com/home-updater) to update a wide range of third-party applications.
- **Configuration**
    - **Configurable Update Types**: Choose which update types to enable (Windows, Office, Winget, PatchMyPC), and any combination thereof, via a JSON config file or interactive menu.
    - **Winget Skip List**: Exclude specific apps from being updated by `winget` using a customizable skip list.
- **First-Time Setup Wizard**: Interactive setup for configuration, including scheduling, log management, and update preferences.
- **Robust Logging**: Logs all actions and results to a configurable directory, with retention and archiving options.
- **Scheduled Task Support**: Easily create or update a Windows Task Scheduler job to run the script automatically on a schedule (daily, weekly, or monthly).
- **Auto-Elevation**: Automatically relaunches itself with administrative privileges if required.
- **Error Handling**: Graceful error handling and informative log messages for troubleshooting.

## <a name='Configuration'></a>Configuration

All settings are stored in `WindowsUpdateConfig.json`. Key options include:
- `logDir`: Directory for log files.
- `wingetSkipList`: List of app names or IDs to exclude from `winget` updates.
- `UpdateTypes`: Which update types to enable (`Windows`, `Office`, `Winget`, `PatchMyPC`).
- `ScheduledTask`: Scheduling options for automated runs.

You can edit this file manually, or use the script's interactive menu.

## <a name='Requirements'></a>Requirements

- **Windows 10/11**
- **PowerShell 5.1+** or **PowerShell Core (pwsh)**
- **winget** (Windows Package Manager)
- **Patch My PC Home Updater** (optional, can be installed by the script)
- **Administrative privileges** (required for most update operations)

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

See the `LICENSE` file in the root of this repository for usage rights and licensing information.

---

*This project is not affiliated with Microsoft or Patch My PC. Use at your own risk.*

# LISAI Executive Notification System

A PowerShell-based internal messaging tool that enables an executive workstation to send real-time notifications to multiple workstations across the office network.

---

## Overview

The LISAI Executive Notification System is a lightweight, network-aware messaging utility built entirely in PowerShell. It provides a graphical interface for composing and dispatching notifications to one or more target workstations within a local domain — without requiring third-party software, cloud services, or internet access.

The system is designed for internal organizational use and is intended to run exclusively from a designated executive workstation.

---

## Purpose

This tool addresses the operational need to send timely, centralized notifications from executive or administrative personnel to specific staff workstations on-site. It is suitable for environments where a simple, self-contained, and controllable messaging solution is preferred over enterprise-scale communication platforms.

---

## Main Features

- Graphical user interface built with Windows Forms via PowerShell
- Send notifications to one, several, or all registered workstations simultaneously
- Target workstations are configured via a JSON file — no code changes required to add or remove recipients
- Runs directly from a UNC network path via desktop shortcut
- No installation required on target workstations beyond standard Windows networking
- Operates entirely within a local domain — no external dependencies

---

## System Requirements

| Component | Requirement |
|---|---|
| **Executive Workstation OS** | Windows 10 / Windows 11 |
| **PowerShell Version** | 5.1 or later (built-in on Windows 10/11) |
| **Network** | All machines must be on the same local domain |
| **File Server** | A shared network path accessible to the executive workstation (e.g., `\\SRV-01\LISAI Messaging System\`) |
| **Permissions** | Executive workstation must have read access to the shared folder |
| **Remote Messaging** | The `MSG` command or equivalent must be functional on target workstations |

---

## Recommended Naming Conventions

### Repository Name
```
lisai-executive-notification-system
```

### Main Project Folder
```
LISAI Messaging System
```

### PowerShell Script
```
LISAI-Messenger.ps1
```

### JSON Configuration File
```
workstations.json
```

### Optional Folders

| Folder | Purpose |
|---|---|
| `App/` | Contains the main PowerShell script |
| `Config/` | Contains `workstations.json` and any environment-specific settings |
| `Assets/` | Icons, images, or branding resources |
| `Docs/` | Internal documentation, screenshots, or deployment notes |

---

## Recommended Folder Structure

```
LISAI Messaging System/
├── App/
│   └── LISAI-Messenger.ps1
├── Config/
│   └── workstations.json
├── Assets/
│   └── icon.ico
├── Docs/
│   └── (internal documentation)
└── README.md
```

---

## Deployment and Setup

### 1. Place Files on the File Server

Copy the project folder to the designated shared network location:

```
\\SRV-01\LISAI Messaging System\
```

Ensure the share is accessible from the executive workstation with at least **read** permissions.

### 2. Configure Target Workstations

Open `Config/workstations.json` and add the PC names of all target workstations in the local domain. See the [Configuration](#configuration) section for format details.

### 3. Create a Desktop Shortcut on the Executive Workstation

Create a new shortcut on the executive workstation's desktop with the following target:

```
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\SRV-01\LISAI Messaging System\App\LISAI-Messenger.ps1"
```

**Shortcut settings:**

| Field | Value |
|---|---|
| **Target** | *(command above)* |
| **Start in** | `\\SRV-01\LISAI Messaging System\App\` |
| **Name** | `LISAI Messenger` |
| **Icon** | *(optional)* `Assets\icon.ico` |

> **Note:** No installation or setup is required on target workstations. They only need to be online and reachable within the domain.

---

## Configuration

### `workstations.json`

This file defines the list of workstations that will appear as notification targets in the application.

**Format:**

```json
{
  "workstations": [
    { "name": "WORKSTATION-01", "display": "Reception" },
    { "name": "WORKSTATION-02", "display": "Finance" },
    { "name": "WORKSTATION-03", "display": "IT Department" }
  ]
}
```

| Key | Description |
|---|---|
| `name` | The actual PC/computer name as registered in the domain |
| `display` | A human-readable label shown in the application UI |

To add or remove a target workstation, edit this file only — no changes to the script are necessary.

---

## Usage

1. Launch the application via the **LISAI Messenger** desktop shortcut on the executive workstation.
2. The UI will load and display the list of registered workstations from `workstations.json`.
3. Select one or more target workstations from the list.
4. Compose your notification message in the message field.
5. Click **Send** to dispatch the notification to all selected workstations.
6. A confirmation or error indicator will be displayed for each attempted delivery.

---

## Troubleshooting

### Notification not received on target workstation

- Confirm the target PC is powered on and connected to the domain network.
- Verify the PC name in `workstations.json` matches the actual machine name exactly (case-insensitive, but must be accurate).
- Ensure the **Messenger** service or equivalent remote message delivery is enabled and not blocked by firewall rules on either machine.
- Test network reachability: run `ping WORKSTATION-NAME` from the executive workstation.

### Application fails to launch

- Confirm the UNC path `\\SRV-01\LISAI Messaging System\` is accessible from the executive workstation.
- Check that the shortcut target path is correctly entered and has not changed.
- Ensure PowerShell 5.1 or later is available on the executive workstation.

### Script loads but workstation list is empty

- Verify that `Config/workstations.json` exists in the expected path relative to the script.
- Validate the JSON structure for syntax errors (use a JSON linter if needed).
- Confirm the script has read access to the `Config/` folder on the network share.

### Execution policy error on launch

- The shortcut already includes `-ExecutionPolicy Bypass`. If this error appears, confirm the shortcut target has not been modified.
- As an alternative, an administrator can set the machine-level execution policy: `Set-ExecutionPolicy RemoteSigned -Scope LocalMachine`

---

## Notes and Operational Reminders

- This system is intended for use **only** on the designated executive workstation. It should not be deployed to or launched from other machines.
- All target workstations must be members of the **same local domain** as the executive workstation. Cross-domain or off-network delivery is not supported.
- The `workstations.json` file is the single configuration source for recipients. Keep it updated as workstations are added, renamed, or decommissioned.
- Avoid embedding sensitive information (credentials, personal data, etc.) in the script or configuration files.
- If the file server path or share name changes, update the desktop shortcut accordingly.

---

## Summary

The LISAI Executive Notification System is a self-contained, domain-local messaging utility that requires no installation on target workstations and no external services. It is configured through a single JSON file and launched from a desktop shortcut on the executive workstation. The system is straightforward to deploy, maintain, and extend as organizational needs evolve.

---

*For internal use only. Not intended for public distribution.*

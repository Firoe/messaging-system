# 🚀 LISAI Messaging System

**A lightweight, secure internal messaging system for enterprise environments.**

Built entirely in PowerShell, it enables instant communication between departments across a local area network (LAN) using a standard Windows shared folder as a backend. No complex servers, no databases, just pure efficiency.

---

## 📋 Features

- 💬 **Instant Messaging**: Real-time chat interface for all network users.
- 🏢 **Departmental Organization**: Grouped contacts based on company departments.
- 🔔 **Desktop Notifications**: Visual alerts (toasts) for incoming messages.
- 🟢 **Presence Tracking**: Real-time online/away/offline status indicators.
- 📂 **No Database Required**: Uses zero-config JSON and file-based storage on a network share.
- 🔒 **Secure & Private**: All data stays within your corporate network.

---

## 🗂️ Project Structure

```
messaging-system/
├── app/
│   ├── messenger.ps1       # Main GUI application script
│   └── start.cmd           # Launcher for end-users
├── config/
│   └── clients.json        # Central list of all PC endpoints
├── data/
│   └── clients/            # Shared message storage (one folder per PC)
├── logs/                   # System and error logs
└── README.md
```

---

## 🚀 Getting Started

### 1. Server Setup
1. Create a shared folder on your network (e.g., `\\YOUR-SERVER\Messaging-System`).
2. Ensure all users have **Read/Write** permissions to this folder.
3. Copy the `config`, `data`, and `logs` folders to this share.

### 2. Client Configuration
1. Open `app/messenger.ps1` and update the `$ServerRoot` variable to point to your network share.
2. Update `config/clients.json` with the computer names and departments of your users.

### 3. Usage
Users can launch the system by running:
```batch
app/start.cmd
```

---

## ⚙️ Requirements

| Requirement | Details |
|---|---|
| OS | Windows 10 / 11 / Windows Server 2016+ |
| PowerShell | Version 5.1 or later |
| Permissions | Read/Write access to the backend network share |
| Network | LAN / VPN connection with line-of-sight to server |

---

## 🔒 Security Notes

- This tool is designed for **internal network use only**.
- Access is controlled via Windows File Share permissions.
- No data is transmitted over the internet or stored in the cloud.


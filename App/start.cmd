@echo off
:: ==============================================================================
:: Messaging System Launcher
:: Description: Launches the PowerShell messaging client with secure parameters.
:: ==============================================================================
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\YOUR-SERVER\Messaging-System\app\messenger.ps1"
exit /b
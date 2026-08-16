# Requires -Version 5.1
<#
.SYNOPSIS
    Custom Intune Win32 App Detection Script for SecureContacts.
.DESCRIPTION
    Checks HKLM Uninstall keys (64-bit and 32-bit/WOW6432Node) for SecureContacts.
    Evaluates presence and version compliance.
    
    Intune Requirements:
    - Exit Code 0 + STDOUT output = Detected (Installed/Up to Date)
    - Exit Code 1 (or any non-zero) with NO output = Not Detected (Triggers Install/Upgrade)
#>

[CmdletBinding()]
param(
    [string]$AppName = "Secure Contacts",
    [string]$MinimumVersion = "0.8.0"
)

$ErrorActionPreference = 'SilentlyContinue'

# 1. Define standard Windows Uninstall Registry paths
$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# 2. Query registry for matching DisplayName
$InstalledApp = Get-ItemProperty -Path $UninstallPaths | 
    Where-Object { $_.DisplayName -like "*$AppName*" } | 
    Select-Object -First 1

if ($InstalledApp) {
    $CurrentVersionString = $InstalledApp.DisplayVersion

    # Parse versions using [version] cast for reliable comparison (e.g., 1.2.10 vs 1.2.2)
    try {
        $CurrentVersion = [version]$CurrentVersionString
        $TargetMinimum  = [version]$MinimumVersion

        if ($CurrentVersion -ge $TargetMinimum) {
            # STDOUT output + Exit 0 tells Intune: "Application is present and compliant"
            Write-Output "Detected: $($InstalledApp.DisplayName) (Version: $CurrentVersionString)"
            exit 0
        } else {
            # Less than minimum version: Exit 1 without output signals Intune to trigger an update
            exit 1
        }
    } catch {
        # Fallback if DisplayVersion isn't a standard semantic version string
        Write-Output "Detected: $($InstalledApp.DisplayName) (Version: $CurrentVersionString)"
        exit 0
    }
} else {
    # App not found in registry: Exit 1 tells Intune the app needs installation
    exit 1
}
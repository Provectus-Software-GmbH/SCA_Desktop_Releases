# Secure Contacts — Windows Deployment Files

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices.

This folder contains the files IT administrators need to configure and manage SCA on Windows devices via Microsoft Intune. The included deployment script is also suitable for SCCM/MECM when you want the same MSI install logic outside Intune. Two policy-configuration methods are supported: ADMX/ADML imported templates and OMA-URI custom profiles (manual or PowerShell-automated via Graph).

**Start here:** [SCA-Intune-Config-Manual-Win.md](SCA-Intune-Config-Manual-Win.md) for policy configuration and [SCA-Intune-Win32-Deploy-Manual-Win.md](SCA-Intune-Win32-Deploy-Manual-Win.md) for Intune Win32 packaging, packaged-local MSI usage, and SCCM/MECM-compatible deployment.

## Files in this folder

| File | Role |
|---|---|
| [SCA-Intune-Config-Manual-Win.md](SCA-Intune-Config-Manual-Win.md) | Full Intune configuration guide (Method A: ADMX, Method B: OMA-URI) |
| [SCA-Intune-Win32-Deploy-Manual-Win.md](SCA-Intune-Win32-Deploy-Manual-Win.md) | Windows app deployment guide — Intune Win32 packaging, packaged-local MSI usage, SCCM/MECM-compatible deployment |
| [secure-contacts.admx](secure-contacts.admx) | ADMX policy schema — required for both Intune methods |
| [secure-contacts.adml](secure-contacts.adml) | Matching ADML locale labels for the ADMX |
| [secure-contacts.intune-oma-uri.md](secure-contacts.intune-oma-uri.md) | Blank OMA-URI row template for manual Intune entry |
| [secure-contacts.intune-oma-uri.example.md](secure-contacts.intune-oma-uri.example.md) | Filled OMA-URI reference showing valid sample values |
| [secure-contacts.intune-omauri-profile.json](secure-contacts.intune-omauri-profile.json) | Blank Graph API payload for the PowerShell importer |
| [secure-contacts.intune-omauri-profile.ready.json](secure-contacts.intune-omauri-profile.ready.json) | Ready-to-use Graph payload with the current ADMX content already embedded |
| [secure-contacts.intune-omauri-profile.example.json](secure-contacts.intune-omauri-profile.example.json) | Filled Graph payload reference showing valid sample values |
| [import-secure-contacts-omauri.ps1](import-secure-contacts-omauri.ps1) | PowerShell script — creates the Intune profile via Microsoft Graph |
| [README.intune-omauri-import.md](README.intune-omauri-import.md) | Quick-start guide for the PowerShell importer |
| [Install-SecureContacts.ps1](Install-SecureContacts.ps1) | Windows install/update script — default GitHub-download mode or optional packaged-local MSI mode for Intune/SCCM |
| [Test-SecureContactsInstalled.ps1](Test-SecureContactsInstalled.ps1) | Intune Win32 app detection script — checks registry for installed version compliance |
| [Test-SecureContactsUpToDate.ps1](Test-SecureContactsUpToDate.ps1) | Intune Win32 app detection script — compares the installed version with the latest eligible GitHub release |

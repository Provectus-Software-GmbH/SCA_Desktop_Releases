# Secure Contacts — Windows Deployment Files

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices.

This folder contains the files IT administrators need to configure and manage SCA on Windows devices via Microsoft Intune. The included deployment script is also suitable for SCCM/MECM when you want the same MSI install logic outside Intune. Two policy-configuration methods are supported: ADMX/ADML imported templates and OMA-URI custom profiles (manual or PowerShell-automated via Graph).

**Start here:** [README.Intune-Config-Win.md](README.Intune-Config-Win.md) for policy configuration, [README.Intune-Win32-Deploy-Win.md](README.Intune-Win32-Deploy-Win.md) for managed app deployment, and [README.Intune-Publisher-Win.md](README.Intune-Publisher-Win.md) for validated MSI publishing automation. For optional data cleanup, see [README.Intune-Uninstall.md](README.Intune-Uninstall.md).

## Files in this folder

| File | Role |
|---|---|
| [README.Intune-Config-Win.md](README.Intune-Config-Win.md) | Full Intune configuration guide (Method A: ADMX, Method B: OMA-URI) |
| [README.Intune-Win32-Deploy-Win.md](README.Intune-Win32-Deploy-Win.md) | Windows app deployment guide — Intune Win32 packaging, packaged-local MSI usage, SCCM/MECM-compatible deployment |
| [README.Intune-Publisher-Win.md](README.Intune-Publisher-Win.md) | Validated GitHub MSI staging and gated Intune publishing — client-secret testing and certificate production authentication |
| [README.Intune-Uninstall.md](README.Intune-Uninstall.md) | Windows uninstall modes, safety scope, Intune usage, and exit codes |
| [Scripts/Install-SecureContacts.ps1](Scripts/Install-SecureContacts.ps1) | Windows install/update script — default GitHub-download mode or optional packaged-local MSI mode for Intune/SCCM |
| [Scripts/Sync-SecureContactsToIntune.ps1](Scripts/Sync-SecureContactsToIntune.ps1) | Publisher automation — validates, packages, and optionally publishes a signed GitHub MSI to Intune |
| [Scripts/Uninstall-SecureContacts.ps1](Scripts/Uninstall-SecureContacts.ps1) | Optional Windows application-only uninstall or complete per-user data purge script |
| [Scripts/Test-SecureContactsInstalled.ps1](Scripts/Test-SecureContactsInstalled.ps1) | Intune Win32 app detection script — checks registry for installed version compliance |
| [Scripts/Test-SecureContactsUpToDate.ps1](Scripts/Test-SecureContactsUpToDate.ps1) | Intune Win32 app detection script — compares the installed version with the latest eligible GitHub release |
| [ADMX/secure-contacts.admx](ADMX/secure-contacts.admx) | ADMX policy schema — required for both Intune methods |
| [ADMX/secure-contacts.adml](ADMX/secure-contacts.adml) | Matching ADML locale labels for the ADMX |
| [OMA-URI/README.Intune-OMA-URI.md](OMA-URI/README.Intune-OMA-URI.md) | Blank OMA-URI row template for manual Intune entry |
| [OMA-URI/README.Intune-OMA-URI.Example.md](OMA-URI/README.Intune-OMA-URI.Example.md) | Filled OMA-URI reference showing valid sample values |
| [OMA-URI/README.Intune-OMA-URI-Import.md](OMA-URI/README.Intune-OMA-URI-Import.md) | Quick-start guide for the PowerShell importer |
| [OMA-URI/secure-contacts.intune-omauri-profile.json](OMA-URI/secure-contacts.intune-omauri-profile.json) | Blank Graph API payload for the PowerShell importer |
| [OMA-URI/secure-contacts.intune-omauri-profile.ready.json](OMA-URI/secure-contacts.intune-omauri-profile.ready.json) | Ready-to-use Graph payload with the current ADMX content already embedded |
| [OMA-URI/secure-contacts.intune-omauri-profile.example.json](OMA-URI/secure-contacts.intune-omauri-profile.example.json) | Filled Graph payload reference showing valid sample values |
| [OMA-URI/import-secure-contacts-omauri.ps1](OMA-URI/import-secure-contacts-omauri.ps1) | PowerShell script — creates the Intune profile via Microsoft Graph |

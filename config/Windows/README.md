# Secure Contacts — Windows Deployment Files

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices.

This folder contains the Windows policy configuration assets for Secure Contacts. It does not contain application installation, detection, or publishing scripts. Use the repository's script-assisted and CI documentation for update operations against an existing Intune app.

**Start here:** [README.Intune-Config-Win.md](README.Intune-Config-Win.md) for policy configuration. For application updates, see the [script-assisted guide](../../script-assisted/README.md), [GitHub Actions guide](../../.github/README.md), or [Azure DevOps guide](../../.azure-pipelines/README.md). For removal, see the [Windows uninstall guide](../../uninstall/README.Intune-Uninstall.win.md).

## Files in this folder

| File | Role |
|---|---|
| [README.Intune-Config-Win.md](README.Intune-Config-Win.md) | Full Intune configuration guide (Method A: ADMX, Method B: OMA-URI) |
| [README.Intune-Win32-Deploy-Win.md](README.Intune-Win32-Deploy-Win.md) | Existing-app update workflow and manual Intune prerequisites |
| [../../script-assisted/Sync-SecureContactsToIntune.ps1](../../script-assisted/Sync-SecureContactsToIntune.ps1) | Windows validation and update entry point |
| [../../script-assisted/README.md](../../script-assisted/README.md) | Direct script execution, authentication, What-If, and output artifacts |
| [../../.github/README.md](../../.github/README.md) | GitHub Actions publishing workflow |
| [../../.azure-pipelines/README.md](../../.azure-pipelines/README.md) | Azure DevOps publishing workflow |
| [../../uninstall/Uninstall-SecureContacts.ps1](../../uninstall/Uninstall-SecureContacts.ps1) | Windows application removal and optional data purge |
| [../../uninstall/README.Intune-Uninstall.win.md](../../uninstall/README.Intune-Uninstall.win.md) | Windows uninstall modes, safety scope, Intune usage, and exit codes |
| [ADMX/secure-contacts.admx](ADMX/secure-contacts.admx) | ADMX policy schema — required for both Intune methods |
| [ADMX/secure-contacts.adml](ADMX/secure-contacts.adml) | Matching ADML locale labels for the ADMX |
| [OMA-URI/README.Intune-OMA-URI.md](OMA-URI/README.Intune-OMA-URI.md) | Blank OMA-URI row template for manual Intune entry |
| [OMA-URI/README.Intune-OMA-URI.Example.md](OMA-URI/README.Intune-OMA-URI.Example.md) | Filled OMA-URI reference showing valid sample values |
| [OMA-URI/README.Intune-OMA-URI-Import.md](OMA-URI/README.Intune-OMA-URI-Import.md) | Quick-start guide for the PowerShell importer |
| [OMA-URI/secure-contacts.intune-omauri-profile.json](OMA-URI/secure-contacts.intune-omauri-profile.json) | Blank Graph API payload for the PowerShell importer |
| [OMA-URI/secure-contacts.intune-omauri-profile.ready.json](OMA-URI/secure-contacts.intune-omauri-profile.ready.json) | Ready-to-use Graph payload with the current ADMX content already embedded |
| [OMA-URI/secure-contacts.intune-omauri-profile.example.json](OMA-URI/secure-contacts.intune-omauri-profile.example.json) | Filled Graph payload reference showing valid sample values |
| [OMA-URI/import-secure-contacts-omauri.ps1](OMA-URI/import-secure-contacts-omauri.ps1) | PowerShell script — creates the Intune profile via Microsoft Graph |

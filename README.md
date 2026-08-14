# Secure Contacts App (SCA) Desktop Releases

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices.

This repository publishes official SCA Desktop releases and the supporting files IT administrators need to configure and manage the app via Microsoft Intune or other MDM platforms on Windows and macOS.

It contains:
- Windows installers (.exe/.msi)
- macOS installation packages (.pkg/.dmg)
- Release notes
- Intune configuration manuals (Windows and macOS)
- ADMX/ADML administrative template files (Windows)
- OMA-URI templates and Graph API JSON payloads (Windows)
- PowerShell Graph importer script (Windows)
- plist configuration files and MDM manifest (macOS)

The Secure Contacts App source code is maintained in a separate private repository and is not published here.

## Windows deployment files

| File | Role |
|---|---|
| [SCA-Intune-Config-Manual-Win.md](Windows/SCA-Intune-Config-Manual-Win.md) | Full Intune configuration guide (Method A: ADMX, Method B: OMA-URI) |
| [secure-contacts.admx](Windows/secure-contacts.admx) | ADMX policy schema — required for both Intune methods |
| [secure-contacts.adml](Windows/secure-contacts.adml) | Matching ADML locale labels for the ADMX |
| [secure-contacts.intune-oma-uri.md](Windows/secure-contacts.intune-oma-uri.md) | Blank OMA-URI row template for manual Intune entry |
| [secure-contacts.intune-oma-uri.example.md](Windows/secure-contacts.intune-oma-uri.example.md) | Filled OMA-URI reference showing valid sample values |
| [secure-contacts.intune-omauri-profile.json](Windows/secure-contacts.intune-omauri-profile.json) | Blank Graph API payload for the PowerShell importer |
| [secure-contacts.intune-omauri-profile.example.json](Windows/secure-contacts.intune-omauri-profile.example.json) | Filled Graph payload reference showing valid sample values |
| [import-secure-contacts-omauri.ps1](Windows/import-secure-contacts-omauri.ps1) | PowerShell script — creates the Intune profile via Microsoft Graph |
| [README.intune-omauri-import.md](Windows/README.intune-omauri-import.md) | Quick-start guide for the PowerShell importer |

## macOS deployment files

| File | Role |
|---|---|
| [SCA-Intune-Config-Manual-Mac.md](MacOS/SCA-Intune-Config-Manual-Mac.md) | Full Intune configuration guide (plist method + non-Intune MDM) |
| [de.provectus.SecureContactsDesktop.plist](MacOS/de.provectus.SecureContactsDesktop.plist) | Blank plist config template for production use |
| [de.provectus.SecureContactsDesktop.plist.demo](MacOS/de.provectus.SecureContactsDesktop.plist.demo) | Demo plist with sample values (reference only) |
| [secure-contacts-manifest.json](MacOS/secure-contacts-manifest.json) | Manifest schema reference for non-Intune MDM platforms (Jamf, Kandji) |

## About Secure Contacts App

Secure Contacts App (SCA) is an enterprise contact management solution that enables organizations to securely manage, synchronize, and distribute business contacts while maintaining full control over corporate contact data.

Learn more at [Secure Contacts App](https://secure-contacts.com).

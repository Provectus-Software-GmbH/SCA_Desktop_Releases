# Secure Contacts App (SCA) Desktop Releases

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices. Learn more at [secure-contacts.com](https://secure-contacts.com).

This repository publishes official SCA Desktop releases and the supporting files IT administrators need to configure and manage the app via Microsoft Intune or other MDM platforms on Windows and macOS.

It contains:

- Windows installers (.exe/.msi)
- macOS installation packages (.pkg/.dmg)
- Release notes
- Intune configuration manuals (Windows and macOS)
- ADMX/ADML administrative template files (Windows)
- OMA-URI templates and Graph API JSON payloads (Windows)
- PowerShell Graph importer script (Windows)
- PowerShell Win32 app deploy and detect scripts (Windows)
- plist configuration files and MDM manifest (macOS)

The Secure Contacts App source code is maintained in a separate private repository and is not published here.

## Quick start

1. Download the latest SCA Desktop release package and deployment files.
2. Review the appropriate deployment guide:
   - Windows configuration: [SCA-Intune-Config-Manual-Win.md](Windows/SCA-Intune-Config-Manual-Win.md)
   - Windows app deployment: [SCA-Intune-Win32-Deploy-Manual-Win.md](Windows/SCA-Intune-Win32-Deploy-Manual-Win.md)
   - macOS: [SCA-Intune-Config-Manual-Mac.md](MacOS/SCA-Intune-Config-Manual-Mac.md)
3. Configure Secure Contacts for your environment.
4. Deploy the application and assign the configuration through your device management platform.
5. Validate the deployment on a test device.

## Application packages

Prebuilt installation packages are published through GitHub Releases.

Supported package types:

- Windows: `.msi`, `.exe`
- macOS: `.pkg`, `.dmg`

See the repository Releases page for the latest version.

## Windows deployment files

| File | Role |
|---|---|
| [`SCA-Intune-Config-Manual-Win.md`](Windows/SCA-Intune-Config-Manual-Win.md) | Full Intune configuration guide (Method A: ADMX, Method B: OMA-URI) |
| [`SCA-Intune-Win32-Deploy-Manual-Win.md`](Windows/SCA-Intune-Win32-Deploy-Manual-Win.md) | Intune Win32 app deployment guide — packaging, install/detect scripts, uninstall |
| [`secure-contacts.admx`](Windows/secure-contacts.admx) | ADMX policy schema — required for both Intune methods |
| [`secure-contacts.adml`](Windows/secure-contacts.adml) | Matching ADML locale labels for the ADMX |
| [`secure-contacts.intune-oma-uri.md`](Windows/secure-contacts.intune-oma-uri.md) | Blank OMA-URI row template for manual Intune entry |
| [`secure-contacts.intune-oma-uri.example.md`](Windows/secure-contacts.intune-oma-uri.example.md) | Filled OMA-URI reference showing valid sample values |
| [`secure-contacts.intune-omauri-profile.json`](Windows/secure-contacts.intune-omauri-profile.json) | Blank Graph API payload for the PowerShell importer |
| [`secure-contacts.intune-omauri-profile.ready.json`](Windows/secure-contacts.intune-omauri-profile.ready.json) | Ready-to-use Graph payload with the current ADMX content already embedded |
| [`secure-contacts.intune-omauri-profile.example.json`](Windows/secure-contacts.intune-omauri-profile.example.json) | Filled Graph payload reference showing valid sample values |
| [`import-secure-contacts-omauri.ps1`](Windows/import-secure-contacts-omauri.ps1) | PowerShell script — creates the Intune profile via Microsoft Graph |
| [`README.intune-omauri-import.md`](Windows/README.intune-omauri-import.md) | Quick-start guide for the PowerShell importer |
| [`Deploy-SecureContacts.ps1`](Windows/Deploy-SecureContacts.ps1) | Intune Win32 app install/update script — downloads and installs the latest MSI from GitHub Releases |
| [`Detect-SecureContacts.ps1`](Windows/Detect-SecureContacts.ps1) | Intune Win32 app detection script — checks registry for installed version compliance |

## macOS deployment files

| File | Role |
|---|---|
| [`SCA-Intune-Config-Manual-Mac.md`](MacOS/SCA-Intune-Config-Manual-Mac.md) | Full Intune configuration guide (plist method + non-Intune MDM) |
| [`de.provectus.SecureContactsDesktop.plist`](MacOS/de.provectus.SecureContactsDesktop.plist) | Blank plist config template for production use |
| [`de.provectus.SecureContactsDesktop.plist.demo`](MacOS/de.provectus.SecureContactsDesktop.plist.demo) | Demo plist with sample values (reference only) |
| [`secure-contacts-manifest.json`](MacOS/secure-contacts-manifest.json) | Manifest schema reference for non-Intune MDM platforms (Jamf, Kandji) |

## Additional documentation

- Windows deployment and configuration: [`Windows/SCA-Intune-Config-Manual-Win.md`](Windows/SCA-Intune-Config-Manual-Win.md)
- macOS deployment and configuration: [`MacOS/SCA-Intune-Config-Manual-Mac.md`](MacOS/SCA-Intune-Config-Manual-Mac.md)
- Official policy documentation: [Secure Contacts Policy Documentation](https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca)
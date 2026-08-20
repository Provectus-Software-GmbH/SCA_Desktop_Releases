# Secure Contacts App (SCA) Desktop Releases

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices. Learn more at [secure-contacts.com](https://secure-contacts.com).

This repository publishes official SCA Desktop releases and the supporting files IT administrators need to configure and manage the app via Microsoft Intune, SCCM/MECM, or other MDM platforms on Windows and macOS.

It contains:

- Windows installers (.exe/.msi)
- macOS installation packages (.pkg/.dmg)
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
   - Windows app deployment: [SCA-Intune-Win32-Deploy-Manual-Win.md](Windows/SCA-Intune-Win32-Deploy-Manual-Win.md) for Intune Win32 packaging and SCCM/MECM-compatible scripted deployment
   - macOS app deployment: [SCA-Intune-Deploy-Manual-MacOS.md](MacOS/SCA-Intune-Deploy-Manual-MacOS.md) for Intune PKG deployment
   - macOS configuration: [SCA-Intune-Config-Manual-Mac.md](MacOS/SCA-Intune-Config-Manual-Mac.md)
   - optional macOS update automation: [SCA-AutoUpdate-Pipeline-Manual-MacOS.md](MacOS/SCA-AutoUpdate-Pipeline-Manual-MacOS.md) for customer-owned polling, validation, and Graph publishing design
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
| [`SCA-Intune-Win32-Deploy-Manual-Win.md`](Windows/SCA-Intune-Win32-Deploy-Manual-Win.md) | Windows app deployment guide — Intune Win32 packaging, SCCM/MECM-compatible scripted deployment, install/detect scripts, uninstall |
| [`Install-SecureContacts.ps1`](Windows/Install-SecureContacts.ps1) | Windows install/update script — default GitHub-download mode or optional packaged-local MSI mode for Intune/SCCM deployments |
| [`Test-SecureContactsInstalled.ps1`](Windows/Test-SecureContactsInstalled.ps1) | Intune Win32 app detection script — checks registry for installed version compliance |
| [`Test-SecureContactsUpToDate.ps1`](Windows/Test-SecureContactsUpToDate.ps1) | Intune Win32 app detection script — compares the installed version with the latest eligible GitHub release |
| [`ADMX/secure-contacts.admx`](Windows/ADMX/secure-contacts.admx) | ADMX policy schema — required for both Intune methods |
| [`ADMX/secure-contacts.adml`](Windows/ADMX/secure-contacts.adml) | Matching ADML locale labels for the ADMX |
| [`OMA-URI/secure-contacts.intune-oma-uri.md`](Windows/OMA-URI/secure-contacts.intune-oma-uri.md) | Blank OMA-URI row template for manual Intune entry |
| [`OMA-URI/secure-contacts.intune-oma-uri.example.md`](Windows/OMA-URI/secure-contacts.intune-oma-uri.example.md) | Filled OMA-URI reference showing valid sample values |
| [`OMA-URI/secure-contacts.intune-omauri-profile.json`](Windows/OMA-URI/secure-contacts.intune-omauri-profile.json) | Blank Graph API payload for the PowerShell importer |
| [`OMA-URI/secure-contacts.intune-omauri-profile.ready.json`](Windows/OMA-URI/secure-contacts.intune-omauri-profile.ready.json) | Ready-to-use Graph payload with the current ADMX content already embedded |
| [`OMA-URI/secure-contacts.intune-omauri-profile.example.json`](Windows/OMA-URI/secure-contacts.intune-omauri-profile.example.json) | Filled Graph payload reference showing valid sample values |
| [`OMA-URI/import-secure-contacts-omauri.ps1`](Windows/OMA-URI/import-secure-contacts-omauri.ps1) | PowerShell script — creates the Intune profile via Microsoft Graph |
| [`OMA-URI/README.intune-omauri-import.md`](Windows/OMA-URI/README.intune-omauri-import.md) | Quick-start guide for the PowerShell importer |

## macOS deployment files

| File | Role |
|---|---|
| [`SCA-Intune-Deploy-Manual-MacOS.md`](MacOS/SCA-Intune-Deploy-Manual-MacOS.md) | macOS app deployment guide - PKG verification, Intune upload, detection, assignment, updates, and rollback planning |
| [`SCA-AutoUpdate-Pipeline-Manual-MacOS.md`](MacOS/SCA-AutoUpdate-Pipeline-Manual-MacOS.md) | Manual and optional customer-owned macOS update pipeline, validation, approval, and Graph publishing design |
| [`Invoke-SecureContactsAutoUpdate.sh`](MacOS/Invoke-SecureContactsAutoUpdate.sh) | Validation-only macOS runner for AutoPkg-staged artifacts; Graph publishing is disabled |
| [`SCA-Intune-Config-Manual-Mac.md`](MacOS/SCA-Intune-Config-Manual-Mac.md) | Full Intune configuration guide (plist method + non-Intune MDM) |
| [`de.provectus.SecureContactsDesktop.plist`](MacOS/de.provectus.SecureContactsDesktop.plist) | Blank plist config template for production use |
| [`de.provectus.SecureContactsDesktop.plist.demo`](MacOS/de.provectus.SecureContactsDesktop.plist.demo) | Demo plist with sample values (reference only) |
| [`secure-contacts-manifest.json`](MacOS/secure-contacts-manifest.json) | Manifest schema reference for non-Intune MDM platforms (Jamf, Kandji) |
| [`de.provectus.securecontacts.download.recipe.yaml`](MacOS/de.provectus.securecontacts.download.recipe.yaml) | AutoPkg download and Developer ID signature verification recipe |
| [`de.provectus.securecontacts.intune.recipe.yaml`](MacOS/de.provectus.securecontacts.intune.recipe.yaml) | AutoPkg staging recipe for the ARM64 package and official checksum |
| [`de.provectus.securecontacts.config.recipe.yaml`](MacOS/de.provectus.securecontacts.config.recipe.yaml) | AutoPkg staging recipe for macOS configuration templates |

## Additional documentation

- Windows deployment and configuration: [`Windows/SCA-Intune-Config-Manual-Win.md`](Windows/SCA-Intune-Config-Manual-Win.md)
- macOS app deployment: [`MacOS/SCA-Intune-Deploy-Manual-MacOS.md`](MacOS/SCA-Intune-Deploy-Manual-MacOS.md)
- macOS configuration: [`MacOS/SCA-Intune-Config-Manual-Mac.md`](MacOS/SCA-Intune-Config-Manual-Mac.md)
- Official policy documentation: [Secure Contacts Policy Documentation](https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca)
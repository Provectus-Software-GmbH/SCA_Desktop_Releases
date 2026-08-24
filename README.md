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
   - Windows configuration: [README.Intune-Config-Win.md](Windows/README.Intune-Config-Win.md)
   - Windows app deployment: [README.Intune-Win32-Deploy-Win.md](Windows/README.Intune-Win32-Deploy-Win.md) for Intune Win32 packaging and SCCM/MECM-compatible scripted deployment
   - Windows automated publishing: [README.Intune-Publisher-Win.md](Windows/README.Intune-Publisher-Win.md) for validated MSI packaging and gated Intune publishing
   - Windows update paths: [README.Intune-Update-Options-Win.md](Windows/README.Intune-Update-Options-Win.md) for Intune-managed GitHub release, packaged-local MSI, and organization-owned Graph publishing
   - Windows GitHub Actions automation: [README.Intune-GitHub-Actions.md](Windows/README.Intune-GitHub-Actions.md) and [gh-publish-sca-intune-win.yml](.github/workflows/gh-publish-sca-intune-win.yml)
   - Windows Azure DevOps automation: [README.Intune-Azure-DevOps.md](Windows/README.Intune-Azure-DevOps.md) and [azure-publish-sca-intune-win.yml](Windows/.azure-pipelines/azure-publish-sca-intune-win.yml)
   - Windows application removal: [README.Intune-Uninstall.md](Windows/README.Intune-Uninstall.md) for application-only uninstall and optional complete data purge
   - macOS app deployment: [README.Intune-Deploy-MacOS.md](MacOS/README.Intune-Deploy-MacOS.md) for Intune PKG deployment
   - macOS configuration: [README.Intune-Config-MacOS.md](MacOS/README.Intune-Config-MacOS.md)
   - macOS application removal: [README.Intune-Uninstall.MacOS.md](MacOS/README.Intune-Uninstall.MacOS.md) for application-only uninstall and optional complete data purge
   - macOS update paths: [README.Intune-Update-Options-MacOS.md](MacOS/README.Intune-Update-Options-MacOS.md) for manual GitHub, automated staging, and organization-owned Graph publishing
   - macOS Azure DevOps automation: [README.Intune-Azure-DevOps.md](MacOS/README.Intune-Azure-DevOps.md) and [azure-publish-sca-intune-macos.yml](MacOS/.azure-pipelines/azure-publish-sca-intune-macos.yml)
   - macOS GitHub Actions automation: [README.Intune-GitHub-Actions.md](MacOS/README.Intune-GitHub-Actions.md) and [gh-publish-sca-intune-macos.yml](.github/workflows/gh-publish-sca-intune-macos.yml)
   - macOS update-path comparison: [Choose an update path](MacOS/README.Intune-Update-Options-MacOS.md#choose-an-update-path)
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
| [`README.Intune-Config-Win.md`](Windows/README.Intune-Config-Win.md) | Full Intune configuration guide (Method A: ADMX, Method B: OMA-URI) |
| [`README.Intune-Win32-Deploy-Win.md`](Windows/README.Intune-Win32-Deploy-Win.md) | Windows app deployment guide — Intune Win32 packaging, SCCM/MECM-compatible scripted deployment, install/detect scripts, uninstall |
| [`Scripts/Install-SecureContacts.ps1`](Windows/Scripts/Install-SecureContacts.ps1) | Windows install/update script — default GitHub-download mode or optional packaged-local MSI mode for Intune/SCCM deployments |
| [`README.Intune-Publisher-Win.md`](Windows/README.Intune-Publisher-Win.md) | Validated GitHub MSI staging and gated Intune publishing automation for administrator workstations and CI/CD |
| [`README.Intune-Update-Options-Win.md`](Windows/README.Intune-Update-Options-Win.md) | Windows update paths, detection behavior, approval, and organization-owned Graph publishing design |
| [`README.Intune-GitHub-Actions.md`](Windows/README.Intune-GitHub-Actions.md) | GitHub Actions implementation guide for organization-owned Windows Graph publishing |
| [`gh-publish-sca-intune-win.yml`](.github/workflows/gh-publish-sca-intune-win.yml) | Customer-operated GitHub Actions validation and gated Intune publishing workflow |
| [`README.Intune-Azure-DevOps.md`](Windows/README.Intune-Azure-DevOps.md) | Azure DevOps implementation guide for organization-owned Windows Graph publishing |
| [`azure-publish-sca-intune-win.yml`](Windows/.azure-pipelines/azure-publish-sca-intune-win.yml) | Customer-operated Azure DevOps validation and gated Intune publishing pipeline |
| [`Scripts/Uninstall-SecureContacts.ps1`](Windows/Scripts/Uninstall-SecureContacts.ps1) | Optional Windows application-only uninstall or complete per-user data purge script |
| [`Scripts/Test-SecureContactsInstalled.ps1`](Windows/Scripts/Test-SecureContactsInstalled.ps1) | Intune Win32 app detection script — checks registry for installed version compliance |
| [`Scripts/Test-SecureContactsUpToDate.ps1`](Windows/Scripts/Test-SecureContactsUpToDate.ps1) | Intune Win32 app detection script — compares the installed version with the latest eligible GitHub release |
| [`ADMX/secure-contacts.admx`](Windows/ADMX/secure-contacts.admx) | ADMX policy schema — required for both Intune methods |
| [`ADMX/secure-contacts.adml`](Windows/ADMX/secure-contacts.adml) | Matching ADML locale labels for the ADMX |
| [`OMA-URI/README.Intune-OMA-URI.md`](Windows/OMA-URI/README.Intune-OMA-URI.md) | Blank OMA-URI row template for manual Intune entry |
| [`OMA-URI/README.Intune-OMA-URI.Example.md`](Windows/OMA-URI/README.Intune-OMA-URI.Example.md) | Filled OMA-URI reference showing valid sample values |
| [`OMA-URI/secure-contacts.intune-omauri-profile.json`](Windows/OMA-URI/secure-contacts.intune-omauri-profile.json) | Blank Graph API payload for the PowerShell importer |
| [`OMA-URI/secure-contacts.intune-omauri-profile.ready.json`](Windows/OMA-URI/secure-contacts.intune-omauri-profile.ready.json) | Ready-to-use Graph payload with the current ADMX content already embedded |
| [`OMA-URI/secure-contacts.intune-omauri-profile.example.json`](Windows/OMA-URI/secure-contacts.intune-omauri-profile.example.json) | Filled Graph payload reference showing valid sample values |
| [`OMA-URI/import-secure-contacts-omauri.ps1`](Windows/OMA-URI/import-secure-contacts-omauri.ps1) | PowerShell script — creates the Intune profile via Microsoft Graph |
| [`OMA-URI/README.Intune-OMA-URI-Import.md`](Windows/OMA-URI/README.Intune-OMA-URI-Import.md) | Quick-start guide for the PowerShell importer |
| [`README.Intune-Uninstall.md`](Windows/README.Intune-Uninstall.md) | Windows uninstall modes, safety scope, Intune usage, and exit codes |

## macOS deployment files

| File | Role |
|---|---|
| [`README.Intune-Deploy-MacOS.md`](MacOS/README.Intune-Deploy-MacOS.md) | macOS app deployment guide - PKG verification, Intune upload, detection, assignment, updates, and rollback planning |
| [`README.Intune-Uninstall.MacOS.md`](MacOS/README.Intune-Uninstall.MacOS.md) | Optional macOS application-only uninstall or complete per-user data purge guide |
| [`Scripts/Uninstall-SecureContacts.sh`](MacOS/Scripts/Uninstall-SecureContacts.sh) | Intune macOS Shell script for validated application removal and optional complete data purge |
| [`README.Intune-Update-Options-MacOS.md`](MacOS/README.Intune-Update-Options-MacOS.md) | macOS update paths, validation, approval, and optional Graph publishing design |
| [`README.Intune-Azure-DevOps.md`](MacOS/README.Intune-Azure-DevOps.md) | Azure DevOps implementation guide for the organization-owned macOS Graph pipeline |
| [`azure-publish-sca-intune-macos.yml`](MacOS/.azure-pipelines/azure-publish-sca-intune-macos.yml) | Customer-operated Azure DevOps validation and gated Intune publishing pipeline |
| [`README.Intune-GitHub-Actions.md`](MacOS/README.Intune-GitHub-Actions.md) | GitHub Actions implementation guide for the organization-owned macOS Graph pipeline |
| [`gh-publish-sca-intune-macos.yml`](.github/workflows/gh-publish-sca-intune-macos.yml) | Customer-operated GitHub Actions validation and gated Intune publishing workflow |
| [`Scripts/Validate-SecureContactsPackage.sh`](MacOS/Scripts/Validate-SecureContactsPackage.sh) | Graph-free macOS runner that stages and validates ARM64 artifacts; Graph publishing is disabled |
| [`README.Intune-Config-MacOS.md`](MacOS/README.Intune-Config-MacOS.md) | Full Intune configuration guide (plist method + non-Intune MDM) |
| [`plist/de.provectus.SecureContactsDesktop.plist`](MacOS/plist/de.provectus.SecureContactsDesktop.plist) | Blank plist config template for production use |
| [`plist/de.provectus.SecureContactsDesktop.plist.demo`](MacOS/plist/de.provectus.SecureContactsDesktop.plist.demo) | Demo plist with sample values (reference only) |
| [`plist/secure-contacts-manifest.json`](MacOS/plist/secure-contacts-manifest.json) | Manifest schema reference for non-Intune MDM platforms (Jamf, Kandji) |
| [`de.provectus.securecontacts.download.recipe.yaml`](MacOS/AutoPkg/de.provectus.securecontacts.download.recipe.yaml) | AutoPkg download and Developer ID signature verification recipe |
| [`de.provectus.securecontacts.intune.recipe.yaml`](MacOS/AutoPkg/de.provectus.securecontacts.intune.recipe.yaml) | AutoPkg staging recipe for the ARM64 package and official checksum |
| [`de.provectus.securecontacts.config.recipe.yaml`](MacOS/AutoPkg/de.provectus.securecontacts.config.recipe.yaml) | AutoPkg staging recipe for macOS configuration templates |

## Additional documentation

- Windows deployment and configuration: [`Windows/README.Intune-Config-Win.md`](Windows/README.Intune-Config-Win.md)
- macOS app deployment: [`MacOS/README.Intune-Deploy-MacOS.md`](MacOS/README.Intune-Deploy-MacOS.md)
- macOS configuration: [`MacOS/README.Intune-Config-MacOS.md`](MacOS/README.Intune-Config-MacOS.md)
- macOS application removal: [`MacOS/README.Intune-Uninstall.MacOS.md`](MacOS/README.Intune-Uninstall.MacOS.md)
- Official policy documentation: [Secure Contacts Policy Documentation](https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca)
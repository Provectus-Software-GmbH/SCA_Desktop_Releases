# Secure Contacts macOS Deployment Files

This folder contains the signed Secure Contacts PKG, Intune deployment documentation, managed configuration templates, validation tooling, and the optional uninstall tooling.

## Start here

1. Deploy the app with [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md).
2. Configure managed preferences with [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md).
3. Compare and operate the three supported update paths in [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md).
4. Use the [GitHub Actions guide](README.Intune-GitHub-Actions.md) or [Azure DevOps guide](README.Intune-Azure-DevOps.md) for the full Graph publishing path.
5. For application removal or data cleanup, use the separate uninstall guide and [Uninstall-SecureContacts.sh](Scripts/Uninstall-SecureContacts.sh).

## Supported update paths

| Path | Flow |
|---|---|
| Manual | Download, verify, prepare the validated PKG, and upload it in Intune. |
| Semi-automated staging | The sync script downloads and verifies the PKG; an administrator uploads it in Intune. |
| Full automatic Graph publishing | The sync script downloads, verifies, and publishes to an existing Intune macOS PKG app. |

The semi-automated and full paths run on an administrator Mac, an Azure DevOps macOS agent, or a GitHub Actions macOS runner. See the update guide for commands and approval rules.

## Key files

| File | Role |
|---|---|
| [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md) | Initial Intune PKG deployment and portal workflow |
| [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md) | The three supported update paths |
| [README.Intune-GitHub-Actions.md](README.Intune-GitHub-Actions.md) | GitHub Actions implementation of full Graph publishing |
| [README.Intune-Azure-DevOps.md](README.Intune-Azure-DevOps.md) | Azure DevOps implementation of full Graph publishing |
| [Scripts/Validate-SecureContactsPackage.sh](Scripts/Validate-SecureContactsPackage.sh) | Graph-free signed ARM64 PKG validator |
| [Scripts/Sync-SecureContactsToIntune.sh](Scripts/Sync-SecureContactsToIntune.sh) | Single download, staging, validation, and optional Graph publishing entry point |
| [Scripts/Uninstall-SecureContacts.sh](Scripts/Uninstall-SecureContacts.sh) | Separate Intune macOS uninstall script |
| [.azure-pipelines/azure-publish-sca-intune-macos.yml](.azure-pipelines/azure-publish-sca-intune-macos.yml) | Customer-operated Azure DevOps pipeline |
| [../.github/workflows/gh-publish-sca-intune-macos.yml](../.github/workflows/gh-publish-sca-intune-macos.yml) | Customer-operated GitHub Actions workflow |
| [plist/de.provectus.SecureContactsDesktop.plist](plist/de.provectus.SecureContactsDesktop.plist) | Production managed-preferences template |
| [plist/de.provectus.SecureContactsDesktop.plist.demo](plist/de.provectus.SecureContactsDesktop.plist.demo) | Demo managed-preferences template |
| [plist/secure-contacts-manifest.json](plist/secure-contacts-manifest.json) | Non-Intune MDM manifest reference |

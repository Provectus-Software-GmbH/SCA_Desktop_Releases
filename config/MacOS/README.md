# Secure Contacts macOS Deployment Files

This folder contains the macOS managed-configuration templates and references for Secure Contacts. Application validation, publishing, and removal scripts are maintained in their repository-owned folders.

## Start here

1. Configure managed preferences with [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md).
2. Validate and update an existing app with the [script-assisted guide](../../script-assisted/README.md).
3. Use the [GitHub Actions guide](../../.github/README.md) or [Azure DevOps guide](../../.azure-pipelines/README.md) for pipeline publishing.
4. For application removal or data cleanup, use the [macOS uninstall guide](../../uninstall/README.Intune-Uninstall.macos.md).

## Supported update paths

| Path | Flow |
|---|---|
| Manual | Download and verify a release, then update the existing app through approved Intune procedures. |
| Script-assisted | The sync script downloads, verifies, and optionally publishes to an existing Intune macOS PKG app. |
| Pipeline automation | CI runs the sync script with centralized secrets, artifacts, and approvals. |

The script-assisted path runs on an administrator Mac. Pipeline paths run on the configured Azure DevOps macOS agent or GitHub Actions macOS runner. See the linked guides for commands and approval rules.

## Key files

| File | Role |
|---|---|
| [../../script-assisted/Validate-SecureContactsPackage.sh](../../script-assisted/Validate-SecureContactsPackage.sh) | Graph-free signed ARM64 PKG validator |
| [../../script-assisted/Sync-SecureContactsToIntune.sh](../../script-assisted/Sync-SecureContactsToIntune.sh) | Download, validation, and optional existing-app publishing entry point |
| [../../uninstall/Uninstall-SecureContacts.sh](../../uninstall/Uninstall-SecureContacts.sh) | Separate Intune macOS uninstall script |
| [../../.azure-pipelines/azure-publish-sca-intune-macos.yml](../../.azure-pipelines/azure-publish-sca-intune-macos.yml) | Customer-operated Azure DevOps pipeline |
| [../../.github/workflows/github-publish-sca-intune-macos.yml](../../.github/workflows/github-publish-sca-intune-macos.yml) | Customer-operated GitHub Actions workflow |
| [plist/de.provectus.SecureContactsDesktop.plist](plist/de.provectus.SecureContactsDesktop.plist) | Production managed-preferences template |
| [plist/de.provectus.SecureContactsDesktop.plist.demo](plist/de.provectus.SecureContactsDesktop.plist.demo) | Demo managed-preferences template |
| [plist/secure-contacts-manifest.json](plist/secure-contacts-manifest.json) | Non-Intune MDM manifest reference |

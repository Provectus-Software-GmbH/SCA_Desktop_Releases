# Secure Contacts — macOS Deployment Files

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices.

This folder contains the files IT administrators need to deploy, configure, and manage SCA on macOS devices. Intune application deployment uses the signed PKG, while managed configuration uses a plist-based profile. A separate configuration path covers non-Intune MDM platforms such as Jamf and Kandji.

**Start here:**

1. Deploy the app with [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md).
2. Configure managed preferences with [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md).
3. For optional application removal or complete data cleanup, use [README.Intune-Uninstall.MacOS.md](README.Intune-Uninstall.MacOS.md) and [Scripts/Uninstall-SecureContacts.sh](Scripts/Uninstall-SecureContacts.sh).
4. To compare or operate any of the three supported macOS update paths, use [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md).
5. To operate Path 1 from Azure DevOps Pipelines, use [README.Intune-Azure-DevOps.md](README.Intune-Azure-DevOps.md) and [azure-publish-sca-intune-macos.yml](.azure-pipelines/azure-publish-sca-intune-macos.yml).
6. To operate Path 1 from GitHub Actions, use [README.Intune-GitHub-Actions.md](README.Intune-GitHub-Actions.md) and [gh-publish-sca-intune-macos.yml](../.github/workflows/gh-publish-sca-intune-macos.yml).

## Choose an update path

| Path | Best for | Tradeoff |
|---|---|---|
| Manual GitHub download | Small or infrequent deployments | Repeat the download, validation, and Intune upload for each release |
| Automated staging with manual Intune upload | Repeatable package acquisition and validation without Graph | Requires AutoPkg; Intune upload and approval remain manual |
| Organization-owned Graph pipeline | Centralized, auditable approval and publishing | Requires your CI, Graph permissions, credentials, and maintenance |

For the detailed comparison and decision guidance, see [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md#choose-an-update-path).

## Files in this folder

| File | Role |
|---|---|
| [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md) | Full Intune configuration guide (plist method + non-Intune MDM) |
| [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md) | Initial Intune PKG app deployment, verification, detection, assignment, and post-install checks |
| [README.Intune-Uninstall.MacOS.md](README.Intune-Uninstall.MacOS.md) | Optional macOS application-only uninstall or complete per-user data purge guide |
| [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md) | Three macOS update paths: organization-owned Graph publishing, automated staging with manual upload, and manual GitHub download |
| [README.Intune-Azure-DevOps.md](README.Intune-Azure-DevOps.md) | Azure DevOps implementation guide for the organization-owned macOS Graph pipeline |
| [.azure-pipelines/azure-publish-sca-intune-macos.yml](.azure-pipelines/azure-publish-sca-intune-macos.yml) | Customer-operated Azure DevOps validation and gated Intune publishing pipeline |
| [README.Intune-GitHub-Actions.md](README.Intune-GitHub-Actions.md) | GitHub Actions implementation guide for the organization-owned macOS Graph pipeline |
| [../.github/workflows/gh-publish-sca-intune-macos.yml](../.github/workflows/gh-publish-sca-intune-macos.yml) | Customer-operated GitHub Actions validation and gated Intune publishing workflow |
| [Scripts/Uninstall-SecureContacts.sh](Scripts/Uninstall-SecureContacts.sh) | Intune macOS Shell script for validated application removal and optional complete data purge |
| [Scripts/Validate-SecureContactsPackage.sh](Scripts/Validate-SecureContactsPackage.sh) | Graph-free ARM64 PKG staging and validation runner; never writes to Graph |
| [Scripts/Sync-SecureContactsToIntune.sh](Scripts/Sync-SecureContactsToIntune.sh) | Validation orchestration entry point with read-only decisioning and guarded existing-app beta Graph publishing |
| [plist/de.provectus.SecureContactsDesktop.plist](plist/de.provectus.SecureContactsDesktop.plist) | Blank plist config template for production use |
| [plist/de.provectus.SecureContactsDesktop.plist.demo](plist/de.provectus.SecureContactsDesktop.plist.demo) | Demo plist with sample values (reference only) |
| [plist/secure-contacts-manifest.json](plist/secure-contacts-manifest.json) | Manifest schema reference for non-Intune MDM platforms |
| [de.provectus.securecontacts.download.recipe.yaml](AutoPkg/de.provectus.securecontacts.download.recipe.yaml) | Downloads the latest stable ARM64 package and verifies the Provectus signing chain |
| [de.provectus.securecontacts.intune.recipe.yaml](AutoPkg/de.provectus.securecontacts.intune.recipe.yaml) | Stages the verified package and official SHA256 file for Intune or CI |
| [de.provectus.securecontacts.config.recipe.yaml](AutoPkg/de.provectus.securecontacts.config.recipe.yaml) | Stages the production, demo, and manifest configuration files |

## Operational references

The update guide contains the complete AutoPkg commands, shared package validation procedure, Graph authentication and publishing flow, approval gates, rollback guidance, and troubleshooting.

- Use [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md) for all three supported update paths.
- Use [de.provectus.securecontacts.download.recipe.yaml](AutoPkg/de.provectus.securecontacts.download.recipe.yaml) to acquire and verify a signed release package with AutoPkg.
- Use [de.provectus.securecontacts.intune.recipe.yaml](AutoPkg/de.provectus.securecontacts.intune.recipe.yaml) to stage the package and matching checksum for Intune or CI.
- Use [Scripts/Validate-SecureContactsPackage.sh](Scripts/Validate-SecureContactsPackage.sh) for Graph-free ARM64 package validation.
- Use [Scripts/Sync-SecureContactsToIntune.sh](Scripts/Sync-SecureContactsToIntune.sh) for validation orchestration and guarded Graph operations.

Treat every recipe output as a deployment candidate. Record its version and SHA256 value, test installation and managed preferences on a pilot device group, retain the approved package for rollback, and promote the same verified bytes through deployment rings.

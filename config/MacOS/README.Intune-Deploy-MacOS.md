# Secure Contacts - Intune Deployment for macOS

This guide explains how to deploy the signed Secure Contacts ARM64 package to Apple silicon Macs with Microsoft Intune.

For configuration policies, see [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md). For the three supported macOS update paths, see [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md). For the Azure DevOps implementation of the organization-owned Graph pipeline, see [README.Intune-Azure-DevOps.md](README.Intune-Azure-DevOps.md).

## Quick deployment

### Before you start

You need:

- Intune permissions to create and assign macOS applications.
- Enrolled Apple silicon Macs (`arm64`) in your Intune tenant.
- The approved Secure Contacts ARM64 PKG from the [GitHub Releases page](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases).
- The minimum macOS version supported by the Secure Contacts release and your organization.

The documented package is for Apple silicon only. Do not assign it to Intel Macs.

### 1. Download the package

From the approved GitHub release, download the PKG:

```text
SecureContacts-<version>-arm64.pkg
```

For security-sensitive environments, also download the matching checksum file:

```text
SecureContacts-<version>-arm64.pkg.sha256
```

Confirm that both files belong to the same release and have the same version and architecture.

### 2. Verify the package

On a Mac, run these commands from the directory containing the downloaded files:

```bash
shasum -a 256 -c SecureContacts-<version>-arm64.pkg.sha256
pkgutil --check-signature SecureContacts-<version>-arm64.pkg
spctl --assess --type install SecureContacts-<version>-arm64.pkg
```

Continue only when:

- The checksum result is `OK`.
- The signing identity is `Developer ID Installer: Provectus Software GmbH (572S9T76X8)`.
- Gatekeeper accepts the package.

If you do not have a Mac available, use the semi-automated or full macOS runner paths described in [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md). See [README.md](README.md).

### 3. Create the Intune app

1. Open the [Intune Admin Center](https://intune.microsoft.com).
2. Go to **Apps** -> **macOS** -> **Create**.
3. Select **macOS app (PKG)**.
4. Upload `SecureContacts-<version>-arm64.pkg`.
5. Wait for Intune to analyze the package, then continue to **App information**.

Do not select **Line-of-business app**. It is a different Intune app type.

### 4. Enter app information

Use these values where applicable:

| Field | Value |
|---|---|
| Name | Secure Contacts |
| Description | Secure Contacts desktop application for managed macOS devices |
| Publisher | Provectus Software GmbH |
| Developer | Provectus Software GmbH |
| Information URL | `https://secure-contacts.com` |
| Category | Your organization's preferred category |
| Privacy URL | Your approved organizational or vendor privacy URL |
| Logo | The approved Secure Contacts logo, if available |

Keep the bundle identifiers and versions detected by Intune. Do not change package-derived values to work around an upload or detection problem.

### 5. Configure requirements

| Setting | Recommended value |
|---|---|
| Minimum operating system | The oldest macOS version supported by the release and your organization |
| Architecture | Apple silicon / ARM64, if the Intune form provides this setting |

If architecture is not available as an app requirement, assign the app to an Apple silicon device group or use an Intune assignment filter.

### 6. Review detection

Intune displays the bundles detected in the PKG under **Included apps**. Check that the Secure Contacts bundle is present with a bundle identifier and version. Leave version-based detection enabled unless your organization intentionally uses presence-only detection.

### 7. Assign the app

1. Open the **Assignments** tab.
2. Assign the app as **Required** to the intended Apple silicon device group.
3. Use a small pilot group first when introducing a new release.
4. Expand the assignment after the app installs and reports correctly.

Avoid conflicting assignments for the same devices. The macOS PKG app type does not provide a general **Uninstall** assignment.

### 8. Confirm installation

On the app's **Device install status** page, confirm that devices report **Installed** and the detected version matches the approved release. On a test Mac, confirm that Secure Contacts is present and launches successfully.

Deploy application **Configuration** separately using [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md).

## Updating the app

After the initial app deployment, choose exactly one of the three update paths from [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md): manual, semi-automated staging, or full automatic Graph publishing.

The update guide is the single source of truth for subsequent-release download, validation, Intune upload, approval, pilot rollout, rollback, and Graph authentication.

## Troubleshooting

| Problem | Action |
|---|---|
| Upload rejected | Confirm that the file is the original `.pkg`, not a DMG or renamed archive. |
| Checksum or signature fails | Download the PKG and checksum again from the same GitHub release. Stop if the signer differs. |
| Device is not applicable | Check enrollment, macOS version, Apple silicon scope, assignment filters, and group membership. |
| Installation fails | Review Intune device install status and test the same verified PKG on a test Mac. |
| App is reported as not installed | Compare the bundle identifier and version under Intune **Included apps** with the installed application. |
| App installs but is not configured | Deploy the managed-preferences profile described in the configuration guide. |
| Intel Mac is excluded | This is expected. Obtain a supported Intel or universal package before targeting Intel devices. |

For macOS management logs, check:

```text
/Library/Logs/Microsoft/IntuneMDMDaemon/IntuneMDMDaemon.log
```

## Removal and rollback

The macOS PKG app type does not provide a general automatic rollback or **Uninstall** assignment. To roll back, stop or narrow the current assignment, test the older signed PKG, and deploy it only after approval.

For removal, use the separately tested [README.Intune-Uninstall.MacOS.md](README.Intune-Uninstall.MacOS.md) and [Scripts/Uninstall-SecureContacts.sh](Scripts/Uninstall-SecureContacts.sh) workflow. Do not assume that removing an app assignment removes the application or its user data.

## Related files

- [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md) - managed-preferences configuration
- [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md) - canonical guide for all three supported macOS update paths
- [Scripts/Sync-SecureContactsToIntune.sh](Scripts/Sync-SecureContactsToIntune.sh) - self-contained download and publishing entry point

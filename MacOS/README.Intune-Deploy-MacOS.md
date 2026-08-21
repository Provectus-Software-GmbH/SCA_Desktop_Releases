# Secure Contacts - Intune PKG App Deployment Manual (macOS)

This guide covers deploying Secure Contacts to managed Apple silicon Macs as an Intune **macOS app (PKG)**. It uses the signed ARM64 package published in this repository's GitHub Releases.

> **Related:** Configure Secure Contacts policies after app deployment using [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md). For customer-owned AutoPkg/Graph automation, see [README.AutoUpdate-Pipeline-MacOS.md](README.AutoUpdate-Pipeline-MacOS.md). The separate direct endpoint updater is documented below and implemented in [Install-SecureContacts.sh](Install-SecureContacts.sh).

## Scope

This manual covers application deployment and lifecycle operations in Microsoft Intune:

- Acquiring and verifying the official PKG
- Creating a macOS app (PKG) in Intune
- Reviewing package-derived detection metadata
- Assigning and validating the app
- Updating, rolling back, and troubleshooting deployments

Configuration values such as licenses, service URLs, and data-source settings are outside this guide. Deploy them separately with the macOS configuration manual linked above.

## Deployment model

| Item | Value |
|---|---|
| Intune app type | macOS app (PKG) |
| Package architecture | ARM64 (Apple silicon) |
| Package filename | `SecureContacts-<version>-arm64.pkg` |
| Publisher | Provectus Software GmbH |
| Signing identity | `Developer ID Installer: Provectus Software GmbH (572S9T76X8)` |
| Release source | [SCA Desktop Releases](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases) |

This repository does not currently provide an Intel or universal PKG through the documented AutoPkg workflow. Do not assign the ARM64 package to Intel Macs.

## Prerequisites

- Microsoft Intune administrator permissions to create and assign macOS apps.
- Apple silicon Macs enrolled in Intune and able to receive required app assignments.
- A pilot device group separate from production deployment groups.
- Network access from the administrator workstation to GitHub Releases.
- A macOS administrator workstation for the Apple package verification commands in this guide.
- The supported macOS version and any hardware requirements confirmed for the Secure Contacts release you plan to deploy.

Do not infer the minimum supported macOS version from the PKG filename. Select an Intune minimum operating system only after confirming vendor support and completing pilot validation.

## Step 1 - Acquire the release artifacts

Use either the manual or AutoPkg workflow. In both cases, keep the PKG and its matching `.sha256` file together through validation and approval.

### Option A: Download from GitHub Releases

1. Open the [repository Releases page](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases).
2. Select the approved stable release.
3. Download both matching assets:

   ```text
  SecureContacts-<version>-arm64.pkg
  SecureContacts-<version>-arm64.pkg.sha256
   ```

4. Confirm that both filenames contain the same version and architecture.

### Option B: Stage with AutoPkg

On a macOS workstation with AutoPkg 2.3 or later:

```bash
mkdir -p ./artifacts
autopkg run ./MacOS/AutoPkg/de.provectus.securecontacts.intune.recipe.yaml \
  -k OUTPUT_PATH=./artifacts
```

The recipe selects the latest stable ARM64 release, verifies the package's Developer ID certificate chain, and stages the PKG with the publisher-provided checksum file. For complete recipe behavior and cache paths, see [README.md](README.md).

## Step 2 - Verify the package before upload

Run all verification commands from the directory containing the downloaded artifacts:

```bash
cd ./artifacts
shasum -a 256 -c SecureContacts-<version>-arm64.pkg.sha256
pkgutil --check-signature SecureContacts-<version>-arm64.pkg
spctl --assess --type install --verbose=4 SecureContacts-<version>-arm64.pkg
```

Approve the package only when:

- `shasum` reports `OK` for the exact PKG filename.
- `pkgutil` reports a valid chain beginning with:

  ```text
  Developer ID Installer: Provectus Software GmbH (572S9T76X8)
  Developer ID Certification Authority
  Apple Root CA
  ```

- `spctl` accepts the package under the current Gatekeeper policy.

These checks have distinct purposes: SHA256 validates the downloaded bytes against the publisher-provided checksum, `pkgutil` validates the installer signature and publisher identity, and `spctl` performs the current Gatekeeper/notarization assessment. Stop the deployment if any check fails or the expected signer differs.

Record the approved release version, SHA256 value, validation date, and package source in your change record. Promote the same verified PKG bytes through all deployment rings.

## Step 3 - Add the PKG app in Intune

1. In [Intune Admin Center](https://intune.microsoft.com), go to **Apps** -> **macOS** -> **Create**.
2. For **App type**, select **macOS app (PKG)**.
3. Select **App package file**, upload `SecureContacts-<version>-arm64.pkg`, and wait for Intune to finish analyzing the package.
4. Continue to **App information**.

Do not select **Line-of-business app** for this workflow. Its packaging and lifecycle behavior differ from the macOS app (PKG) flow documented here.

## Step 4 - Configure app information

Review package-derived values and complete the administrator-facing metadata.

| Field | Recommended value |
|---|---|
| Name | Secure Contacts |
| Description | Secure Contacts desktop application for managed macOS devices |
| Publisher | Provectus Software GmbH |
| Category | Choose the category used by your organization |
| Show this as a featured app in the Company Portal | No, unless required by your rollout model |
| Information URL | `https://secure-contacts.com` |
| Privacy URL | Use the privacy URL approved by your organization or the vendor |
| Developer | Provectus Software GmbH |
| Owner | Your application owner or endpoint-management team |
| Notes | Record the approved release, SHA256, architecture, and change reference |
| Logo | Add the approved Secure Contacts application logo if available |

Treat the Intune metadata as deployment inventory. Do not alter package-derived identifiers or versions to make an upload pass.

## Step 5 - Configure requirements

Set requirements that match the verified package and your supported-device baseline:

| Setting | Value |
|---|---|
| Minimum operating system | The oldest macOS release explicitly supported and pilot-tested for this Secure Contacts version |
| Architecture | Apple silicon / ARM64 scope only |

If the Intune form does not expose architecture as a requirement for this app type, enforce the scope with an Apple silicon device group or an Intune assignment filter based on device architecture. Confirm the filter result on pilot devices before production assignment.

Add other requirements only when they are backed by tested application or organizational requirements. An unnecessarily high minimum operating system excludes otherwise supported devices; an unverified low value can offer the app to unsupported devices.

## Step 6 - Review Included apps and detection

Intune reads application metadata from the uploaded PKG and presents detected bundles under **Included apps**. These bundle identifiers and versions form the app's installation detection criteria.

1. Review every entry populated by Intune.
2. Confirm that the list represents applications actually installed by the Secure Contacts PKG.
3. Confirm that the Secure Contacts bundle entry has a non-empty bundle identifier and version.
4. Remove an entry only when package inspection and pilot testing prove that it should not participate in detection.
5. Keep version-based detection enabled for normal update management. Use **Ignore app version** only when your organization intentionally wants presence-only detection and has validated the update consequences.

Do not invent an app path, bundle identifier, or version when Intune can read it from the signed package. Preserve a screenshot or export of the Included apps values in the deployment record because these values are release-specific evidence for detection troubleshooting.

## Step 7 - Assign the app

Use deployment rings so that a new release can be observed before broad rollout.

1. Assign **Required** to a small Apple silicon pilot device group.
2. Allow enough time for devices to check in, install, restart the app if necessary, and report status.
3. Expand to broader device groups only after the validation checklist passes.
4. Use **Available for enrolled devices** only when self-service installation through Company Portal fits your support model.

Avoid overlapping assignments that give the same device conflicting intent. Review assignment filters and group membership before rollout.

> **Intune limitation:** macOS app (PKG) does not provide an **Uninstall** assignment intent. Removing a Required assignment or retiring a device does not guarantee that the installed application is removed from the Mac. Plan a separately tested removal workflow if application removal is required.

## Step 8 - Validate on a pilot device

After assigning the pilot group, sync the test Mac from Company Portal or Intune and verify all of the following:

### Intune status

- The device appears under the app's **Device install status**.
- The status reaches **Installed** without recurring retries.
- The detected version matches the approved package release.

### Device state

- Secure Contacts is present and launches successfully.
- The Mac is Apple silicon:

  ```bash
  uname -m
  ```

  Expected output for this package is `arm64`.

- Installer receipts and package metadata can be reviewed without assuming a receipt identifier:

  ```bash
  pkgutil --pkgs | grep -i -E 'secure|contact|provectus'
  ```

- The application bundle metadata shown by Intune matches the installed bundle. Use the path observed on the pilot Mac rather than assuming one:

  ```bash
  defaults read "/path/to/Secure Contacts.app/Contents/Info.plist" CFBundleIdentifier
  defaults read "/path/to/Secure Contacts.app/Contents/Info.plist" CFBundleShortVersionString
  ```

- Core application behavior works with a test account.
- Managed preferences are delivered separately and read by the app as described in [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md).

### Intune management logs

If installation or detection fails, collect relevant entries from the Intune Management Extension log on the Mac:

```text
/Library/Logs/Microsoft/IntuneMDMDaemon/IntuneMDMDaemon.log
```

Log locations and names can change with Microsoft agent updates. If this file is absent, use Microsoft Support documentation for the Intune macOS agent version installed on the device.

## Update workflow

Treat every new release as a new deployment candidate:

1. Acquire the new PKG and matching checksum.
2. Repeat SHA256, signature, and Gatekeeper verification.
3. Test direct installation and upgrade behavior on a representative pilot Mac.
4. In Intune, update the existing Secure Contacts app with the new PKG when the portal supports replacement for the current object. If package replacement is unavailable or the detection metadata changed unexpectedly, create a new app object and transition assignments in controlled phases.
5. Recheck **Included apps**, requirements, assignments, and version-detection behavior.
6. Promote the approved bytes through deployment rings.

Do not enable **Ignore app version** merely to bypass a version or detection mismatch. Investigate package metadata and installed bundle versions first.

## Optional direct endpoint updater

The repository also includes [Install-SecureContacts.sh](Install-SecureContacts.sh), an opt-in customer-owned updater for environments that want devices to download approved releases directly from GitHub. This is a separate Intune macOS shell-script workflow; it does not replace the uploaded PKG app, update the Intune app object, or publish through Microsoft Graph.

Deploy the script only to a pilot group after reviewing it for your organization's change-control requirements. It runs as a machine-level script and:

1. Reads the installed bundle version from `/Applications/SecureContacts.app`.
2. Resolves the latest stable GitHub release.
3. Exits successfully without downloading when the installed version is current.
4. Downloads the matching ARM64 PKG and `.sha256` asset when an update is available.
5. Verifies the checksum, Developer ID signer chain, Gatekeeper assessment, bundle metadata, and ARM64 executable before installation.
6. Installs with `/usr/sbin/installer` only after all checks pass.

Example Intune shell-script command:

```text
/bin/bash Install-SecureContacts.sh
```

The script writes logs under `/Library/Logs/SecureContacts` and uses a lock under `/var/run` to avoid concurrent installations. It refuses to proceed while Secure Contacts is running; the user must close the application and the next scheduled execution can retry. Confirm the Intune macOS shell-script execution schedule and root context on a pilot device because this workflow does not have the same detection/install contract as a Windows Win32 app.

This updater requires outbound access to GitHub Releases and is subject to GitHub availability and rate limits. It is not a substitute for approval rings: keep the script assignment scoped to pilot devices until the release has been approved. It does not uninstall the application, remove user data, modify Keychain items, forget package receipts, or automatically downgrade an installation.

## Rollback and removal

Intune's macOS app (PKG) workflow does not provide a general automatic rollback or Uninstall assignment.

For rollback:

1. Stop or narrow the new release assignment.
2. Determine whether the older signed PKG supports installation over the newer version.
3. Test the downgrade on a non-production Mac, including application data and managed preferences.
4. Deploy the approved rollback package only after successful testing.

For removal, use the separately tested [README.Intune-Uninstall.MacOS.md](README.Intune-Uninstall.MacOS.md) and [Uninstall-SecureContacts.sh](Uninstall-SecureContacts.sh) workflow. It runs as an Intune macOS Shell script rather than as a PKG app Uninstall assignment. Use `application-only` for the conservative removal path; treat `complete-purge` as a separate destructive workflow requiring explicit review, controlled assignment, and acceptance testing.

The PKG app type still has no general Uninstall assignment. Removing an app assignment or retiring a device must not be treated as proof that the application or its user data was removed. The standalone uninstall guide defines the production identity gate, dry-run process, safety checks, preserved managed preferences and Keychain state, best-effort login-item cleanup, and exit codes.

Do not remove `/Library/Managed Preferences/de.provectus.SecureContactsDesktop.plist`, delete user-data directories, remove Keychain items, or run `pkgutil --forget` from an uninstall workflow unless each operation is explicitly approved and tested.

## Troubleshooting

| Symptom | Checks and action |
|---|---|
| Upload rejected | Confirm the asset is the original signed `.pkg`, not a `.dmg`, renamed archive, or modified package. Repeat `pkgutil --check-signature`. |
| Package fails verification | Download both assets again from the same release. Stop if SHA256 still fails or the signer differs. |
| Device remains Not applicable | Check macOS requirement, Apple silicon group/filter scope, enrollment state, and assignment membership. |
| Installation fails | Review Intune device status and macOS management logs; test the same verified PKG locally on a pilot Mac. |
| Installed app is reported as not installed | Compare Intune Included apps bundle IDs and versions with the installed app's `Info.plist`; check the **Ignore app version** setting. |
| Update is not offered | Confirm the uploaded package exposes a newer included-app version and version detection is not being ignored. |
| Repeated reinstall attempts | Look for bundle-version mismatch, missing included app, failed post-install behavior, or an assignment conflict. |
| App installs but is not configured | Deploy and validate the separate managed-preferences profile from the macOS configuration manual. |
| Intel Mac fails or is excluded | Expected for the documented ARM64 package; obtain a supported Intel or universal package before targeting Intel hardware. |

## Operational limitations

- The documented package targets Apple silicon only.
- Package upload does not replace security validation or pilot testing.
- Intune detection depends on the Included apps metadata extracted from each uploaded PKG.
- The macOS app (PKG) app type has no Uninstall assignment intent.
- Assignment removal and device retirement should not be treated as proof of application removal.
- Exact installed paths, receipt identifiers, and minimum supported macOS versions must be verified from the release and a pilot device rather than assumed in automation.

## Related files and references

- [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md) - managed-preferences configuration guide
- [README.AutoUpdate-Pipeline-MacOS.md](README.AutoUpdate-Pipeline-MacOS.md) - manual and optional customer-owned update pipeline
- [README.md](README.md) - AutoPkg staging and verification workflow
- [de.provectus.securecontacts.download.recipe.yaml](AutoPkg/de.provectus.securecontacts.download.recipe.yaml) - package download and signer verification
- [de.provectus.securecontacts.intune.recipe.yaml](AutoPkg/de.provectus.securecontacts.intune.recipe.yaml) - verified PKG and checksum staging
- [Microsoft: Add an unmanaged macOS PKG app to Intune](https://learn.microsoft.com/mem/intune/apps/macos-unmanaged-pkg)
- [Microsoft: Add macOS line-of-business apps to Intune](https://learn.microsoft.com/mem/intune/apps/lob-apps-macos)

# Manual Intune App Creation

This guide describes the one-time manual creation of the Secure Contacts applications in Microsoft Intune. Create and validate the apps before using the repository's update scripts or CI pipelines.

This guide covers application objects only. Configure Secure Contacts policies separately with the [Windows configuration guide](config/Windows/README.Intune-Config-Win.md) or [macOS configuration guide](config/MacOS/README.Intune-Config-MacOS.md).

> **Scope:** This guide covers one-time manual creation and pilot validation of the Windows and macOS Intune app objects. After that, this repository is used to update those existing apps. App assignments, requirements, and other tenant-specific settings remain administrator-managed. The Windows update process may replace the existing MSI ProductCode detection rule when the ProductCode changes; macOS detection rules are not changed.

## Before you start

### Administrator prerequisites

- An Intune administrator account with permission to create and manage applications and assignments.
- A pilot device group for Windows and a pilot device group for macOS.
- Access to the official Secure Contacts releases in [`Provectus-Software-GmbH/SCA_Desktop_Releases`](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases).
- A release version approved for pilot deployment.
- The Microsoft Win32 Content Prep Tool, `IntuneWinAppUtil.exe`, for Windows packaging.
- The Secure Contacts package validation tools and an administrator workstation capable of running them.

Do not place certificates, private keys, tenant secrets, production policy values, or access tokens in this repository.

### Packages covered by this guide

- Windows: the official Secure Contacts MSI.
- macOS: the signed ARM64 Secure Contacts PKG.

Validate the selected packages before uploading them. The update scripts also validate release packages, but that validation does not replace the administrator's pilot test.

### How deployment and configuration work together

Application deployment and Secure Contacts configuration are separate Intune operations, but they should be validated together:

1. Create the app object and configure its requirements, install and uninstall behavior, detection, and pilot assignment.
2. Create the platform configuration profile using the [Windows configuration guide](config/Windows/README.Intune-Config-Win.md) or [macOS configuration guide](config/MacOS/README.Intune-Config-MacOS.md).
3. Assign the application and its corresponding configuration profile to the same pilot device scope, or to scopes whose relationship is intentional and documented.
4. Confirm that the application installs and is detected successfully before validating the managed Secure Contacts settings.
5. Expand both assignments only after the application behavior and effective configuration have been accepted on pilot devices.

Application updates replace package content and release metadata for the existing app; they do not create or update configuration profiles. Profile changes are made and assigned separately by the Intune administrator.

## Windows: create the Win32 app

Create the Windows application once as a manually configured Win32 app. Later Windows releases update this existing object.

### 1. Prepare the package

1. Download the approved Windows MSI from the [official release repository](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases).
2. Inspect the MSI ProductCode and version. The ProductCode is the anchor for the Windows detection rule.
3. Put the MSI in a clean working directory.
4. Package it with Microsoft's Win32 Content Prep Tool:

```powershell
IntuneWinAppUtil.exe -c <working-directory> -s <secure-contacts-msi> -o <output-directory>
```

Use the generated `.intunewin` file for the initial upload. Do not upload the raw MSI as a Win32 app package.

### 2. Create the app object

In the Intune admin center:

1. Go to **Apps** -> **All apps** -> **Create**.
2. Select **Windows app (Win32)**.
3. Upload the generated `.intunewin` file.
4. Enter the Secure Contacts publisher, app name, description, owner, and version information approved by your organization.
5. Keep the app as a device-targeted, per-machine installation unless the release owner has approved a different model.

Choose metadata that remains stable across releases. Release version changes belong in the package and app version metadata maintained by the update process.

### 3. Configure the program settings

Configure a per-machine, silent MSI installation. The initial command must use the exact MSI filename contained in the `.intunewin` package.

- Install behavior: **System**.
- Installation time: sufficient for the MSI and any required prerequisite work.
- Install command: `msiexec /i "SecureContacts-<version>.msi" /qn ALLUSERS=1`.
- Uninstall command: `msiexec /x "{PRODUCT-CODE}" /qn`.
- `/qn` runs the MSI without user interface, and `ALLUSERS=1` requests a per-machine installation.
- Configure restart behavior and return codes according to the organization's standard Win32 application policy. Confirm that the selected MSI supports the chosen behavior.

Replace `<version>` with the actual MSI filename and `{PRODUCT-CODE}` with the ProductCode read from that MSI. The Windows publisher sets these commands again when it publishes a newer release: it uses the current release asset name for installation and the current MSI ProductCode for uninstallation. Keep the initial commands compatible with this same per-machine, silent installation model.

The uninstall command must remove the application without deleting user or managed configuration data unless a separate approved cleanup process is intended.

### 4. Configure requirements

Set requirements to match the supported Secure Contacts fleet and your rollout policy. At minimum, review:

- Operating system architecture.
- Minimum supported Windows version.
- Available disk space.
- Device versus user applicability.
- Any organization-specific prerequisites.

Do not broaden requirements only to make an installation appear successful. Resolve an unsupported-device result with the release owner.

### 5. Add the detection rules

Create exactly one MSI ProductCode detection rule for the installed Secure Contacts application:

1. Select **Manually configure detection rules**.
2. Add an **MSI** rule.
3. Enter the ProductCode from the approved MSI.
4. Enable the rule for a 32-bit app on 64-bit clients only if that matches the actual installation.
5. Do not add a second MSI rule for the same application.
6. Preserve any deliberately configured non-MSI rules only when they are part of the approved app design.

The Windows publisher expects exactly one existing MSI ProductCode rule. When a later release has a different ProductCode, it replaces that MSI rule and preserves unrelated detection rules. If the app has zero or multiple MSI rules, publishing stops before changing Intune.

### 6. Assign and pilot the app

1. Save the app without assigning it broadly.
2. Assign it as **Required** to the Windows pilot device group.
3. Install it on a representative pilot device.
4. Confirm that the application installs as System and that Intune reports it as installed.
5. Confirm that the MSI ProductCode detection rule evaluates successfully.
6. Launch Secure Contacts and verify the expected application behavior.
7. Review install status, error codes, restart behavior, and detection results before expanding the assignment.

Record the app's Intune ID after creation. The ID is required by the Windows update script as `-AppId` and by any CI secret or variable that invokes the publisher.

## macOS: create the PKG app

Create the macOS application once from the signed ARM64 PKG. Later macOS releases update this existing object; the automation does not create or modify its detection rules.

### 1. Prepare and validate the package

1. Download the approved signed ARM64 PKG from the [official release repository](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases).
2. Confirm that the package is intended for the supported ARM64 macOS fleet.
3. Validate the package signature, package identity, bundle identifier, application path, and version before upload.
4. Confirm the package installs the application at:

```text
/Applications/SecureContacts.app
```

The expected bundle identifier is:

```text
de.provectus.SecureContactsDesktop
```

The current repository baseline targets macOS 15 or newer. Confirm the release notes and your organization's support policy before setting the minimum operating-system requirement.

### 2. Create the app object

In the Intune admin center:

1. Go to **Apps** -> **All apps** -> **Create**.
2. Select **macOS app (PKG)**.
3. Upload the signed ARM64 Secure Contacts PKG.
4. Enter stable Secure Contacts metadata, including publisher, name, description, owner, and the approved version.
5. Set the minimum operating system to macOS 15 or the newer baseline approved for the release.
6. Set the supported architecture to Apple silicon/ARM64 when the portal exposes an architecture choice.

Use the official package as the source of truth for package identity and version. Do not upload an unsigned or locally repackaged PKG.

### 3. Review requirements, detection, and assignments

Configure the app for the supported managed-device population:

- Application path: `/Applications/SecureContacts.app`.
- Bundle ID: `de.provectus.SecureContactsDesktop`.
- Architecture: ARM64/Apple silicon.
- Minimum macOS version: macOS 15 or newer, subject to release approval.
- Detection: verify the bundle ID and installed application version using the package metadata and the Intune app settings available in your tenant.
- Assignments: start with a Required assignment to the macOS pilot device group.

Do not add a second detection model merely to compensate for an incorrect bundle ID or installation path. Correct the app metadata or package selection and repeat the pilot validation.

### 4. Assign and pilot the app

1. Save the app without assigning it broadly.
2. Assign it as **Required** to the macOS pilot device group.
3. Install it on a representative ARM64 pilot device.
4. Confirm that `/Applications/SecureContacts.app` exists.
5. Confirm the bundle identifier is `de.provectus.SecureContactsDesktop` and the installed version matches the approved release.
6. Launch Secure Contacts and verify the expected application behavior.
7. Review Intune install status and detection results before expanding the assignment.

Record the app's Intune ID after creation. The ID is required by the macOS update script as `--app-id` and by any CI secret or variable that invokes the publisher.

## Initial rollout sequence

1. Approve a release package from the official release repository.
2. Create the Windows Win32 app and macOS PKG app manually.
3. Configure requirements, install behavior, uninstall behavior, detection, and pilot assignments.
4. Install and validate both apps on pilot devices.
5. Configure platform policies using the [Windows](config/Windows/README.Intune-Config-Win.md) and [macOS](config/MacOS/README.Intune-Config-MacOS.md) configuration guides.
6. Record both Intune app IDs in the protected operations configuration. Do not commit tenant-specific IDs or credentials to the repository.
7. Run validation-only first, then use the What-If flow to compare the approved release with the existing app and validate a newer candidate without packaging, uploading, or changing Intune. Confirm that each app ID resolves to the intended Secure Contacts application.
8. Approve broader assignments only after pilot results are accepted.

## After initial creation

- Run Windows updates from the [Windows update guide](config/Windows/README.Intune-Win32-Deploy-Win.md) or the [script-assisted operations guide](script-assisted/README.md).
- Run macOS updates from the [script-assisted operations guide](script-assisted/README.md).
- Use the [GitHub Actions guide](.github/README.md) or [Azure DevOps guide](.azure-pipelines/README.md) for CI execution.
- Use the [Windows uninstall guide](uninstall/README.Intune-Uninstall.win.md) or [macOS uninstall guide](uninstall/README.Intune-Uninstall.macos.md) for removal and approved data cleanup.

The lifecycle is intentionally split: administrators create and govern the Intune apps, while this repository validates approved releases and updates the existing application content.

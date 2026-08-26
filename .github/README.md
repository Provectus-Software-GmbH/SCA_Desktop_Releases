# Secure Contacts Intune Deployment and Configuration

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices. Learn more at [secure-contacts.com](https://secure-contacts.com).

This repository is the deployment and configuration companion for the official SCA Desktop releases. The signed Windows MSI and macOS PKG release assets are published in the [SCA Desktop Releases repository](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases); this repository provides the documentation, configuration templates, validation tools, and Intune update automation used to manage those releases.

The SCA application source code is maintained separately and is not published in this repository.

It supports two related responsibilities for Secure Contacts desktop apps in Microsoft Intune:

1. **App deployment and updates:** validate releases and update existing Windows and macOS Intune apps through manual, script-assisted, or pipeline-based workflows.
2. **App configuration:** configure the Secure Contacts policies that the applications consume on managed Windows and macOS devices.

The repository is update-only for application lifecycle operations. The target Intune apps, assignments, and device-side detection rules must be created and configured manually in the tenant before automation is used. Publishing never creates a new app, changes assignments, or creates supersedence relationships. Windows publishing replaces the existing MSI detection rule when the MSI ProductCode changes, preserves unrelated rules, and never appends a second MSI rule.

## Quick start

1. Select the appropriate Windows MSI or macOS PKG release from the [SCA Desktop Releases repository](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases).
2. Review the platform configuration guide and prepare the required Intune policy profile:
	- [Windows configuration](config/Windows/README.Intune-Config-Win.md)
	- [macOS configuration](config/MacOS/README.Intune-Config-MacOS.md)
3. Create and configure the target Windows or macOS app manually in Intune, including requirements, assignments, and device-side detection rules. Follow the [Manual Intune App Creation guide](README.Intune-Manual-App-Setup.md) for the complete setup and pilot procedure.
4. Choose an application update method from the deployment section below.
5. Assign the configuration profile and application to a pilot device, then verify the installation and managed settings before broad rollout.

## Start with your task

### Deploy or update the app

Choose the operating system, then select the execution method:

| Platform | Direct scripts and validation | Pipeline documentation | Removal |
| --- | --- | --- | --- |
| Windows | [Windows script-assisted guide](script-assisted/README.md) | [GitHub Actions](.github/README.md) or [Azure DevOps](.azure-pipelines/README.md) | [Windows uninstall guide](uninstall/README.Intune-Uninstall.win.md) |
| macOS | [macOS script-assisted guide](script-assisted/README.md) | [GitHub Actions](.github/README.md) or [Azure DevOps](.azure-pipelines/README.md) | [macOS uninstall guide](uninstall/README.Intune-Uninstall.macos.md) |

The [script-assisted guide](script-assisted/README.md) contains platform-specific prerequisites, validation commands, authentication settings, What-If behavior, output artifacts, and cleanup operations. The CI guides add workflow triggers, secret handling, artifacts, and approval controls.

### Configure the app

Use the platform-specific configuration assets and guides:

| Platform | Configuration method | Entry point |
| --- | --- | --- |
| Windows | Imported ADMX/ADML templates or Windows Policy CSP OMA-URI | [Windows configuration guide](config/Windows/README.Intune-Config-Win.md) |
| macOS | Intune preference-file profile using the Secure Contacts plist | [macOS configuration guide](config/MacOS/README.Intune-Config-MacOS.md) |

Configuration is separate from application publishing. The files under [`config/Windows`](config/Windows) and [`config/MacOS`](config/MacOS) are policy templates and configuration references; they do not install the application or create the Intune app. Configure production values in the tenant or approved profile payloads, assign profiles to the intended device groups, and validate them on pilot devices.

## Official application packages

Prebuilt SCA Desktop packages are published through GitHub Releases in the [SCA Desktop Releases repository](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases).

Supported package types are:

- Windows: `.msi` and `.exe`
- macOS: `.pkg` and `.dmg`

The scripts in this repository resolve the approved release assets, verify their checksums and platform identity, and use them for validation or updates. Keep the release repository as the source of truth for package binaries and this repository as the source of truth for deployment, configuration, and operational documentation.

## App deployment and updates

All supported update paths compare a release with the existing Intune app before making changes.

| Path | Download and verification | Version comparison | Intune update |
| --- | --- | --- | --- |
| Fully manual | Operator | Operator | Operator |
| Script-assisted | PowerShell or Bash script | Script | Script |
| Pipeline automation | Workflow and script | Workflow and script | Workflow and script |

### Fully manual

Use this path when an administrator wants to control every step without using the repository scripts or either pipeline:

1. Select a published release from `Provectus-Software-GmbH/SCA_Desktop_Releases`.
2. Download the platform installer and its matching checksum file.
3. Verify the checksum and package signature or identity using the platform's approved tools.
4. Prepare the installer using the organization's approved Intune packaging process.
5. Compare the release with the existing Intune app version.
6. Update the existing app through Intune administration tools and retain the release, verification, and update records.

This repository does not provide a separate manual packaging command. Follow your organization's Intune packaging and change-control procedures for the exact administrative steps.

### Script-assisted

Run the PowerShell or Bash scripts on an administrator workstation. Start with the [script-assisted README](script-assisted/README.md), which contains the detailed guide and links to the scripts and validator.

### Pipeline automation

Use the existing CI integrations when you need repeatable execution, centralized secret handling, artifacts, cleanup, or approval controls:

- [GitHub Actions](.github/README.md)
- [Azure DevOps](.azure-pipelines/README.md)

Those documents contain platform-specific pipeline triggers, secret configuration, artifact handling, environment approvals, and CI cleanup details.

## Repository map

| Folder | Responsibility |
| --- | --- |
| [`config/Windows`](config/Windows) | Windows ADMX/ADML and OMA-URI policy templates and configuration documentation |
| [`config/MacOS`](config/MacOS) | macOS plist and manifest templates and configuration documentation |
| [`script-assisted`](script-assisted) | Direct Windows and macOS release validation and existing-app update scripts |
| [`uninstall`](uninstall) | Standalone Windows and macOS application removal and optional data cleanup |
| [`.github`](.github) | GitHub Actions workflows and publishing documentation |
| [`.azure-pipelines`](.azure-pipelines) | Azure DevOps pipelines and publishing documentation |

## Configuration assets

| Platform | Included assets |
| --- | --- |
| Windows | ADMX/ADML administrative templates, OMA-URI row templates, Graph API payloads, and an OMA-URI profile importer |
| macOS | Intune preference-file plist templates and a manifest reference for other MDM platforms |

The configuration guides explain which template to use, where production values belong, how to assign the resulting profile, and how to validate managed settings on a pilot device.

## Operating boundary

Application deployment and configuration have different ownership boundaries:

- **Intune administrators** create the initial apps, configure assignments and detection rules, enter production policy values, and approve rollout.
- **This repository** validates release artifacts, packages and updates existing apps when requested, provides configuration templates, and documents operational workflows.
- **The release repository** remains the source of published Windows MSI and macOS PKG assets.

Test every application update and configuration profile on a pilot device before broad assignment. Keep credentials, certificates, private keys, and production policy values out of source control.

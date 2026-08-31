# Secure Contacts App (SCA) Desktop - Admin Quickstart

This guide provides the essential steps to deploy and configure Secure Contacts App (SCA) Desktop using Microsoft Intune. Use the detailed platform guides linked below for the exact portal steps and commands.

The official [SCA Desktop Release Repository](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases) publishes the application packages and provides deployment documentation, configuration templates, validation tools, and update automation.

## Before you start

- Have Intune administrator permissions and a Windows and/or macOS pilot device group.
- Select an approved release from the [SCA Desktop Releases](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases/latest). Review the release notes, supported platforms, architecture requirements, and checksum assets.
- If deploying Windows, have Microsoft's `IntuneWinAppUtil.exe` available.


## 1) Enterprise Application Registration

SCA Desktop uses the SCA Enterprise Application for user authentication:

- The application must be admin-consented in your Microsoft Entra ID tenant.
- SCA Desktop uses the same Enterprise Application as SCA Mobile. If SCA Mobile is already working in your tenant, this consent may already be complete.
- If consent is not complete, follow the [SCA Enterprise Application Setup](https://docs.secure-contacts.com/documentation/authentication/enterprise-application).

## 2) App Configuration

SCA Desktop uses App Configuration to manage application settings, contact data sources, and licensing. Most App Configuration key/value pairs are shared with SCA Mobile, although some settings are platform-specific.

Review the [SCA App Configuration Reference](https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca) before configuring a profile. It identifies which settings are supported on each platform.

Many settings are shared with SCA Mobile. Review the platform support information before reusing existing Mobile configurations, as some settings are platform-specific and not every key is applicable to Desktop.

> **Example:** Typical SCA Desktop deployments configure settings such as `SecContacts.Defaults`, `SecContacts.Licenses`. See the [SCA App Configuration Reference](https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca) for supported values and platform-specific details.

The platform templates and detailed instructions are available in the [SCA Desktop Configuration Templates](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/tree/main/config).

### Windows (ADMX/ADML)

ADMX/ADML templates expose SCA Desktop settings through Intune's **Imported Administrative Templates** interface.

1. Import `config/Windows/ADMX/secure-contacts.admx` and the matching `secure-contacts.adml` into Intune.
2. Create an **Imported Administrative Templates** profile.
3. Configure the SCA settings required by your organization.
4. Assign the profile, preferably to a device group.

This is the recommended configuration method for most Windows deployments. If your organization requires Custom OMA-URI instead, follow the Windows configuration guide.

### macOS: Preference File Profile

1. Start with `config/MacOS/plist/de.provectus.SecureContactsDesktop.plist` and enter the settings required by your organization.
2. This Intune template is a key/value fragment, not a complete plist document. Do not wrap it in `<plist>` or `<dict>` tags.
3. Create a macOS preference-file/custom profile using the completed content.
4. Assign the profile, preferably to a device group.

See the macOS configuration guide for the managed preferences path, supported value formats, and device-side verification.

After the profile is assigned and the device completes an Intune sync, the managed settings should be available to the installed application. Verify the effective settings on a pilot device.

## 3) Create and Pilot the Intune Applications

Application deployment and configuration are separate Intune operations, but they should be validated together on pilot devices.

Follow the [Manual Intune App Creation Guide](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/blob/main/README.Intune-Manual-App-Setup.md) to create the application objects.

1. Validate the approved release package and its checksum before uploading it.
2. Create the Windows Win32 app and/or macOS PKG app manually.
3. Configure requirements, silent installation, uninstall behavior, and detection rules.
   - Windows requires exactly one MSI ProductCode detection rule for the application.
   - macOS requires the correct bundle ID, application path, architecture, and minimum macOS version.
4. Confirm that the corresponding configuration profile from Section 2 is ready.
5. Assign the application and profile to the same pilot device group, or to intentionally coordinated scopes.
6. Confirm that the application installs and Intune detects it successfully before validating managed settings.
7. Expand assignments only after the pilot results are accepted.

After the profile is assigned and the device completes an Intune sync, the managed settings should be available to the installed application. Verify the effective settings on a pilot device rather than relying only on the profile assignment status.

## 4) Optional: Automate Future Updates

After the initial Intune applications have been created and pilot-tested, you can optionally automate future updates using:

- [Script-Assisted Updates](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/blob/main/script-assisted/README.md)
- [Azure DevOps Pipelines](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/blob/main/.azure-pipelines/README.md)
- [GitHub Actions](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/blob/main/.github/README.GitHub-Actions.md)

These tools download the latest approved release, verify the package, prepare it for Intune, and upload it to an existing Intune application. They do not create the initial application or App Configuration profile, and they do not change assignments.

## Pilot Acceptance Checklist

Before broad rollout, confirm on representative pilot devices:

- The correct package installs successfully.
- Intune reports the application as installed and detection succeeds.
- The application launches and user authentication works.
- The configuration profile reports success.
- Effective managed settings are present on the device.
- Contact synchronization and the expected application behavior work correctly.
- No unexpected restart, permissions, or network errors are present.
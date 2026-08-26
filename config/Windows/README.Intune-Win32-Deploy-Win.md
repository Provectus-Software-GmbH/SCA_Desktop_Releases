# Secure Contacts — Windows Intune App Updates

This guide describes the Windows prerequisites for the supported update-only Intune workflow. It does not create the Secure Contacts app, assign it, or provide a device-side installer or dynamic detection script. An administrator must create and configure the target Win32 app manually before using the publisher.

> **Related:** Create the app using the [Manual Intune App Creation guide](../../README.Intune-Manual-App-Setup.md). Configure policies using [README.Intune-Config-Win.md](README.Intune-Config-Win.md). Run the update from the [script-assisted guide](../../script-assisted/README.md), [GitHub Actions guide](../../.github/README.md), or [Azure DevOps guide](../../.azure-pipelines/README.md).

## Supported workflow

1. Create the Windows Win32 app manually in Intune and configure its install, uninstall, requirements, assignments, and device-side detection rules.
2. Verify the app on a pilot device before enabling automation.
3. Run [`script-assisted/Sync-SecureContactsToIntune.ps1`](../../script-assisted/Sync-SecureContactsToIntune.ps1) in validation-only, publish, or What-If mode.
4. Supply the existing Intune app ID when publishing. The script compares the release with the existing app, validates the MSI, packages it when a real update is needed, and updates that app only.

Publishing never creates an app, changes assignments, or creates supersedence relationships. Windows publishing preserves unrelated detection rules and replaces the existing MSI ProductCode rule when the new MSI ProductCode changes. Apps without exactly one existing MSI rule fail closed.

## Prerequisites

- Microsoft Intune administrator permissions.
- An existing Windows `#microsoft.graph.win32LobApp` configured for Secure Contacts.
- A tested device-side detection configuration with exactly one MSI ProductCode rule.
- Microsoft Win32 Content Prep Tool, `IntuneWinAppUtil.exe`, when running a real Windows publish.
- Windows PowerShell or PowerShell 7 with the pinned `IntuneWin32App` module version `1.5.0`.
- Graph application permission `DeviceManagementApps.ReadWrite.All` with admin consent for publish and What-If.
- A certificate registered on the App Registration and available to the script, or a PFX supplied through its certificate parameters.

## Manual Intune setup checklist

Before the first publisher run, create and configure the app in Intune:

1. Add a Windows app (Win32) and configure the Secure Contacts metadata.
2. Configure the MSI installation and uninstall commands approved by your organization.
3. Configure requirements and assignments for the target device population.
4. Add exactly one MSI detection rule for the installed Secure Contacts ProductCode, then test it on a pilot device.
5. Record the app ID and use it as the publisher `-AppId` value.

The publisher updates package content and release metadata. It does not infer or replace the tenant's complete app design.

## Run the publisher

From the repository root, validate a release without Intune credentials:

```powershell
.\script-assisted\Sync-SecureContactsToIntune.ps1 `
    -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases'
```

Preview an update against the existing app without packaging, uploading, or changing Intune:

```powershell
.\script-assisted\Sync-SecureContactsToIntune.ps1 `
    -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
    -TenantId $env:INTUNE_TENANT_ID `
    -ClientId $env:INTUNE_CLIENT_ID `
    -CertificateThumbprint $env:INTUNE_CERTIFICATE_THUMBPRINT `
    -AppId $env:INTUNE_APP_ID `
    -Publish `
    -WhatIf
```

Publish a newer validated release to the existing app:

```powershell
.\script-assisted\Sync-SecureContactsToIntune.ps1 `
    -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
    -TenantId $env:INTUNE_TENANT_ID `
    -ClientId $env:INTUNE_CLIENT_ID `
    -CertificateThumbprint $env:INTUNE_CERTIFICATE_THUMBPRINT `
    -AppId $env:INTUNE_APP_ID `
    -Publish
```

`-WhatIf` still requires Graph authentication and an existing app ID because it reads the target app. Equal or older releases return `NoUpdateRequired` without package work. Review the decision and validation manifests in the output directory after each run.

See [`script-assisted/README.md`](../../script-assisted/README.md) for exact-release selection, certificate options, output artifacts, and troubleshooting. Use the [GitHub Actions](../../.github/README.md) or [Azure DevOps](../../.azure-pipelines/README.md) guides for managed pipeline execution.

## Detection-rule behavior

The existing MSI rule is the anchor for Windows app updates. During publish:

- A matching ProductCode is preserved.
- A changed ProductCode replaces the existing MSI rule.
- Unrelated detection rules are preserved.
- Missing or multiple MSI rules stop the update before writes.

Do not add a second MSI rule manually for a new release. Re-test the resulting detection configuration on a pilot device after publishing.

## Removal

Use the standalone [`uninstall/Uninstall-SecureContacts.ps1`](../../uninstall/Uninstall-SecureContacts.ps1) and its [uninstall guide](../../uninstall/README.Intune-Uninstall.win.md) for application removal or approved data cleanup. Removal is separate from publishing and is not performed by the sync script.

## Related files

- [`README.Intune-Config-Win.md`](README.Intune-Config-Win.md) - Windows policy configuration assets and instructions
- [`../../script-assisted/README.md`](../../script-assisted/README.md) - direct validation, publish, What-If, and authentication details
- [`../../script-assisted/Sync-SecureContactsToIntune.ps1`](../../script-assisted/Sync-SecureContactsToIntune.ps1) - Windows update entry point
- [`../../.github/README.md`](../../.github/README.md) - GitHub Actions workflow
- [`../../.azure-pipelines/README.md`](../../.azure-pipelines/README.md) - Azure DevOps workflow
- [`../../uninstall/README.Intune-Uninstall.win.md`](../../uninstall/README.Intune-Uninstall.win.md) - removal modes and safety scope

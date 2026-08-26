# Secure Contacts Intune GitHub Actions

These workflows validate and optionally publish the Secure Contacts desktop releases to existing Microsoft Intune apps:

- `.github/workflows/github-publish-sca-intune-win.yml`
- `.github/workflows/github-publish-sca-intune-macos.yml`

Both workflows are started with **Run workflow** from the GitHub Actions tab. They expose two required boolean inputs:

- `publish`: compare the release with the existing Intune app and publish only when the release is newer.
- `whatIf`: perform a read-only version comparison and candidate MSI validation. What-If does not package, upload, or modify Intune.

Leave both inputs disabled for validation-only behavior. Publishing is update-only: the supplied app ID must identify an app created and configured manually in Intune, including tested device-side detection rules. Follow the [Manual Intune App Creation guide](../README.Intune-Manual-App-Setup.md) for the initial app setup and pilot procedure. Windows publish replaces the existing MSI detection rule when the MSI ProductCode changes, preserves unrelated rules, and never appends a second MSI rule.

## Required secrets

Configure these repository or environment secrets as appropriate for the repository:

| Secret | Purpose |
| --- | --- |
| `INTUNE_TENANT_ID` | Microsoft Entra Directory (tenant) ID. |
| `INTUNE_CLIENT_ID` | Application (client) ID of the App Registration used for Graph authentication. |
| `INTUNE_APP_ID` | Existing Windows Intune app ID. |
| `INTUNE_MACOS_APP_ID` | Existing macOS Intune app ID. |
| `INTUNE_CERTIFICATE_BASE64` | Base64-encoded certificate bundle used during the run. |
| `INTUNE_CERTIFICATE_PASSWORD` | Password for the certificate bundle. |
| `SECURE_CONTACTS_GITHUB_TOKEN` | Optional token for authenticated access to the release repository or higher GitHub API limits. |
| `SECURE_CONTACTS_MSI_SHA256` | Expected Windows MSI SHA-256 value. |
| `SECURE_CONTACTS_EXPECTED_SIGNER` | Expected Windows package signer identity. |

The certificate must be registered on the App Registration, which requires Microsoft Graph `DeviceManagementApps.ReadWrite.All` application permission with admin consent. Keep all values in GitHub encrypted secrets; do not add them to workflow files.

For `SECURE_CONTACTS_GITHUB_TOKEN`, use a customer-owned fine-grained token with **Contents: Read-only** access to `Provectus-Software-GmbH/SCA_Desktop_Releases` when authenticated access is needed. The token is passed through the step environment and is not written to URLs, manifests, or log messages.

## macOS approvals

The macOS publish job targets the `intune-production` environment. Configure required reviewers and any deployment protection rules on that environment so a real publish pauses for approval. Metadata preflight and validation run before the protected publish job.

## Release source and behavior

Both workflows use the fixed release repository `Provectus-Software-GmbH/SCA_Desktop_Releases`.

Windows installs the pinned `IntuneWin32App` PowerShell module version `1.5.0`. It imports the certificate into the runner's CurrentUser certificate store only for the job, updates the selected existing app when required, uploads audit artifacts, and removes the certificate in an always-run cleanup step.

macOS resolves and downloads the ARM64 PKG through `Sync-SecureContactsToIntune.sh`. Publish and What-If first compare release metadata with the existing app. Package download and validation occur only for a real publish when an update is needed. The validated package is handed to the protected publish job as a workflow artifact. Temporary P12 and password files are removed even when a step fails.

## Artifacts

The workflows upload artifacts even after failed validation or publishing when the runner has created the output directory:

- `secure-contacts-intune-artifacts` for Windows.
- `secure-contacts-macos-intune-artifacts` for macOS preflight and validation.
- `secure-contacts-macos-intune-publish-artifacts` for the macOS publish job.

Validation produces package integrity manifests. Publish and What-If produce a decision manifest describing the candidate release, existing Intune version, selected app ID, decision, and timestamp. What-If validates the candidate MSI but does not create package artifacts or modify Intune.

## Helper scripts

The workflow folder contains the scripts invoked by the workflows:

- `Sync-SecureContactsToIntune.ps1`
- `Sync-SecureContactsToIntune.sh`
- `Validate-SecureContactsPackage.sh`

These copies are kept identical to the source helper scripts used by the other pipeline integration.

# Secure Contacts - Azure DevOps Windows Intune Pipeline

This guide explains how to operate the organization-owned Windows Intune publishing workflow from Azure DevOps. It is the Azure DevOps implementation of the organization-owned Graph publishing path in [README.Intune-Update-Options-Win.md](README.Intune-Update-Options-Win.md), not a separate client update mode.

The example pipeline is [azure-publish-sca-intune-win.yml](.azure-pipelines/azure-publish-sca-intune-win.yml). It runs on a Microsoft-hosted `windows-latest` agent and invokes [Sync-SecureContactsToIntune.ps1](Scripts/Sync-SecureContactsToIntune.ps1).

## What the pipeline does

The manually parameterized pipeline:

1. Installs the pinned `IntuneWin32App` PowerShell module.
2. Imports the protected publishing certificate for Graph-enabled runs.
3. Stages, validates, and packages the latest eligible signed MSI.
4. Optionally reviews the selected Intune action with `whatIf`.
5. Publishes the package when `publish` is enabled and the configured approval allows it.
6. Uploads non-secret audit artifacts and removes the certificate from the agent.

The pipeline updates or creates the configured Intune Win32 app according to the shared publisher contract. It does not assign the app to groups.

## Prerequisites

- An Azure DevOps project connected to this repository.
- A Microsoft-hosted `windows-latest` agent, or an approved Windows self-hosted agent.
- An existing Secure Contacts Intune Win32 app, or an explicit decision to allow the publisher to prepare a new app when no target matches.
- An Entra application with administrator-consented Microsoft Graph application permission `DeviceManagementApps.ReadWrite.All`.
- An organization-managed certificate with a private key for production authentication.
- Protected Azure DevOps variables or a variable group for the values listed below.
- A pipeline approval or check configured before production publishing.

## Add the pipeline

1. Import or connect the repository in Azure DevOps.
2. Create a pipeline from existing YAML.
3. Select `Windows/.azure-pipelines/azure-publish-sca-intune-win.yml` in the repository.
4. Configure an approval or check for the production publishing process before enabling `publish`.
5. Run with both parameters set to `false` for the first validation-only test.

The YAML is selected from the repository path shown above; Azure DevOps does not require the definition to be at the repository root.

## Configure variables and secrets

Create protected pipeline variables or a variable group. Use Azure Key Vault integration where available.

| Name | Type | Purpose |
|---|---|---|
| `INTUNE_TENANT_ID` | Secret | Entra tenant ID used for Graph authentication. |
| `INTUNE_CLIENT_ID` | Secret | Entra publishing application or service principal ID. |
| `INTUNE_CERTIFICATE_BASE64` | Secret | Base64-encoded PFX certificate containing the private key. |
| `INTUNE_CERTIFICATE_PASSWORD` | Secret | Password for the protected PFX certificate. |
| `INTUNE_APP_ID` | Variable | Existing Intune Win32 app object ID. |
| `SECURE_CONTACTS_MSI_SHA256` | Variable | Optional expected SHA-256 value for release pinning. |
| `SECURE_CONTACTS_EXPECTED_SIGNER` | Variable | Optional expected Authenticode signer value. |

Never commit certificate material, passwords, tokens, or tenant-specific values to the repository.

## Run modes

The pipeline has two boolean parameters:

| Parameter | Default | Behavior |
|---|---:|---|
| `publish` | `false` | Submits the validated create/update request when `true`. |
| `whatIf` | `false` | Reviews the selected Intune action without writing when `true` and `publish` is also `true`. |

### Validation only

Run with `publish: false` and `whatIf: false`. The publisher stages, validates, and packages the MSI without Graph authentication or Intune changes.

### Read-only Intune decision

Run with `publish: true` and `whatIf: true`. The publisher authenticates, selects the target, and reports the action without writing to Intune.

### Publish

Run with `publish: true` and `whatIf: false` only after validation and approval. The publisher submits the create/update request to Intune.

The `whatIf` parameter is intended to be used together with `publish`; it does not make a validation-only run query Intune.

## Security and artifacts

The pipeline writes the certificate to the agent temporary directory, imports it into the current-user certificate store, and removes both the temporary file and certificate during unconditional cleanup. The shared publisher writes a non-secret manifest containing release, checksum, signer, MSI, package, target, and decision details. Review and retain the published artifact with the deployment record.

For the publisher parameters, manual certificate examples, target selection rules, and failure behavior, see [README.Intune-Publisher-Win.md](README.Intune-Publisher-Win.md). For the broader update decision, see [README.Intune-Update-Options-Win.md](README.Intune-Update-Options-Win.md).

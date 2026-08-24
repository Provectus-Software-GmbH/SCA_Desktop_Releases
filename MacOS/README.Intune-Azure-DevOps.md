# Secure Contacts - Azure DevOps macOS Intune Pipeline

This guide shows how to run the organization-owned macOS Intune publishing workflow from Azure DevOps Pipelines instead of GitHub Actions. Azure DevOps uses a separate YAML definition, but the package validation and Microsoft Graph publishing behavior is shared with the repository's other automation examples.

This is a customer-operated template. Your organization owns the Azure DevOps project, agent capacity, Entra application, permissions, certificates, approvals, and release process.

## What the pipeline does

The example pipeline is [azure-publish-sca-intune-macos.yml](.azure-pipelines/azure-publish-sca-intune-macos.yml). It runs on a Microsoft-hosted `macOS-latest` agent and:

1. Downloads the latest stable ARM64 PKG and matching SHA256 file from the official GitHub release.
2. Runs [Validate-SecureContactsPackage.sh](Scripts/Validate-SecureContactsPackage.sh) without Graph access.
3. Optionally runs a read-only Graph decision with `whatIf`.
4. Publishes validation artifacts for review.
5. Waits for the Azure DevOps `intune-production` environment approval when `publish` is enabled.
6. Publishes the already validated package through [Sync-SecureContactsToIntune.sh](Scripts/Sync-SecureContactsToIntune.sh).
7. Removes temporary certificate files after the job, including failed jobs.

Azure DevOps does not use GitHub Actions syntax. Do not copy `uses`, `github.token`, `GITHUB_ENV`, or `${{ secrets.* }}` expressions into an Azure Pipelines definition. The YAML file is separate; the shell scripts and validation contract are shared.

## Prerequisites

- An Azure DevOps project with this repository imported or connected.
- A Microsoft-hosted `macOS-latest` agent, or a customer-owned self-hosted Mac with the required Apple package tools.
- An existing Intune macOS app (PKG) object for Secure Contacts.
- An Entra application with administrator-consented Microsoft Graph application permission `DeviceManagementApps.ReadWrite.All`.
- An organization-managed certificate with a private key for the publishing application.
- An Azure DevOps environment named `intune-production` with an approval or check configured before deployment jobs run.

The package validator must run on macOS. It uses Apple tools including `pkgutil`, `spctl`, `plutil`, and `PlistBuddy`; AutoPkg also requires macOS. A Windows agent cannot replace the macOS agent for this workflow.

## Add the pipeline

1. Import or connect the repository in Azure DevOps.
2. Create a pipeline from existing YAML.
3. Select `MacOS/.azure-pipelines/azure-publish-sca-intune-macos.yml` in the repository.
4. Create the `intune-production` environment before enabling publishing.
5. Configure an approval check on that environment. The approval is evaluated only by the `Publish` deployment job.
6. Run the pipeline with both parameters set to `false` for the first validation-only test.

The pipeline has two manual parameters:

| Parameter | Default | Behavior |
|---|---:|---|
| `publish` | `false` | When `true`, runs the publish deployment after validation and environment approval. |
| `whatIf` | `false` | When `true`, performs a read-only Graph version decision during validation. |

Keep `publish` disabled until validation, what-if review, and pilot approval are complete.

## Configure variables and secrets

Create protected pipeline variables or a variable group. Use Azure Key Vault integration where available.

| Name | Type | Purpose |
|---|---|---|
| `INTUNE_TENANT_ID` | Secret | Entra tenant ID used for Graph authentication. |
| `INTUNE_CLIENT_ID` | Secret | Entra application or service principal ID. |
| `INTUNE_CERTIFICATE_BASE64` | Secret | Base64-encoded certificate containing the private key. |
| `INTUNE_CERTIFICATE_PASSWORD` | Secret | Password for the protected PFX/P12 certificate; use an empty protected value only when your certificate does not require one. |
| `INTUNE_MACOS_APP_ID` | Variable | Existing Intune macOS app (PKG) object ID. |

The example writes the certificate and password to temporary files under `$(Agent.TempDirectory)` with restrictive permissions, uses them only for the publishing command, and deletes them in an unconditional cleanup step. Never commit certificate material, passwords, tokens, or tenant-specific values to the repository.

The pipeline downloads releases from this public repository without a GitHub token. If your organization changes the release visibility or needs authenticated GitHub API access, add a protected `GITHUB_TOKEN` secret and update the download step to use it. Do not print the token in logs.

## Authentication and permissions

The Entra application must have the Microsoft Graph **Application** permission `DeviceManagementApps.ReadWrite.All`, with administrator consent. The publishing script obtains a Microsoft Graph token through Azure CLI using the temporary certificate. The Azure DevOps pipeline does not create the app registration, grant consent, rotate certificates, create the Intune app, or change assignments automatically.

For validation-only runs, do not configure Graph credentials unless you are using `whatIf`. The Graph-free validator still checks the checksum, expected Developer ID Installer identity, Gatekeeper acceptance, bundle ID, version, ARM64 executable, and artifact uniqueness.

Workload identity federation or an approved Azure DevOps service connection can replace certificate handling when the customer has implemented that authentication path. The pipeline example currently documents and implements certificate-based authentication because it matches the shared shell-script contract.

## Run modes

### Validation only

Run with:

```text
publish: false
whatIf: false
```

The pipeline downloads the stable release, validates it on macOS, and publishes non-secret validation artifacts. It does not call Microsoft Graph.

### Read-only Graph decision

Run with:

```text
publish: false
whatIf: true
```

The pipeline validates the package and performs the script's read-only Graph version decision. Review `validation-manifest.json` and `decision-manifest.json` before enabling publishing.

### Publish to Intune

Run with:

```text
publish: true
whatIf: false
```

The validation stage must succeed first. Azure DevOps then starts a deployment job associated with `intune-production`; the configured environment approval must pass before the existing Intune app is updated. The publish job downloads the validation artifact and invokes the same `Sync-SecureContactsToIntune.sh --skip-recipe --publish` flow used by the other organization-owned pipeline examples.

The pipeline does not create Intune app objects, assign production devices, remove applications, or delete retained rollback artifacts.

## Rollback and audit

Retain the exact validated PKG, matching checksum, validation manifest, decision manifest, release URL, pipeline run, approval record, and Graph object identifiers according to your change policy. Do not rebuild the package between validation and publishing.

For rollback, stop or narrow the current assignment, select a previously retained and validated package, test it on a pilot Mac, and obtain the required approval. Do not use an older package as an automatic update candidate.

## Troubleshooting

| Problem | Check |
|---|---|
| Apple command is missing | Confirm the job is running on `macOS-latest` or a correctly configured self-hosted Mac. |
| No package is found | Confirm the latest GitHub release has the expected stable tag and both ARM64 assets. |
| Certificate authentication fails | Check the base64 value, private key, password, Entra tenant/client IDs, certificate validity, and Graph administrator consent. |
| Environment approval is not requested | Confirm `publish` is `true` and the deployment environment is named exactly `intune-production`. |
| Graph publishing is rejected | Confirm `INTUNE_MACOS_APP_ID` points to an existing Secure Contacts macOS PKG app, not another platform or app type. |
| Validation fails | Stop the pipeline and investigate the checksum, signer, Gatekeeper, architecture, version, bundle ID, and artifact count. |

For package rules, Graph behavior, cleanup, token testing, and the full three-path decision model, see [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md).

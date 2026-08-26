# Secure Contacts - GitHub Actions Windows Intune Pipeline

This guide explains how to operate the organization-owned Windows Intune publishing workflow with GitHub Actions. It is the CI implementation of the organization-owned Graph publishing path in [README.Intune-Update-Options-Win.md](README.Intune-Update-Options-Win.md), not a separate client update mode.

The workflow is [gh-publish-sca-intune-win.yml](../.github/workflows/gh-publish-sca-intune-win.yml). It uses the shared Windows publisher and does not contain a separate MSI download, validation, or Graph implementation.

## What the workflow does

The manually triggered workflow:

1. Runs on a GitHub-hosted `windows-latest` runner.
2. Installs the pinned `IntuneWin32App` PowerShell module.
3. Imports the protected publishing certificate only for Graph-enabled runs.
4. Stages, validates, and packages the latest eligible signed MSI.
5. Optionally reviews the selected Intune action with `whatIf`.
6. Publishes only when `publish` is enabled and `whatIf` is disabled.
7. Uploads non-secret audit artifacts and removes the certificate from the runner.

The workflow updates or creates the configured Intune Win32 app according to the shared publisher contract. It does not assign the app to groups.

## Repository placement

GitHub only discovers Actions workflows from the root `.github/workflows` directory. If you copy this template into an organization-owned repository, preserve that directory and place the workflow at `.github/workflows/gh-publish-sca-intune-win.yml`. Update the repository name in the workflow if the release source changes.

## Prerequisites

- A GitHub repository with Actions enabled and permission to run the workflow.
- A GitHub-hosted `windows-latest` runner, or an approved Windows self-hosted runner.
- An existing Secure Contacts Intune Win32 app, or an explicit decision to allow the publisher to prepare a new app when no target matches.
- An Entra application with administrator-consented Microsoft Graph application permission `DeviceManagementApps.ReadWrite.All`.
- An organization-managed certificate with a private key for production authentication.
- A GitHub environment named `intune-production` with required reviewers or other protection rules.
- The workflow variables and secrets listed below.

## Configure GitHub Actions

1. Open the repository **Settings** -> **Environments** and create `intune-production`.
2. Add required reviewers and deployment protection rules.
3. Add these repository or environment secrets:

| Secret | Purpose |
|---|---|
| `INTUNE_TENANT_ID` | Entra tenant ID used for Graph authentication. |
| `INTUNE_CLIENT_ID` | Entra publishing application or service principal ID. |
| `INTUNE_CERTIFICATE_BASE64` | Base64-encoded PFX certificate containing the private key. |
| `INTUNE_CERTIFICATE_PASSWORD` | Password for the protected PFX certificate. |

4. Add these repository or environment variables:

| Variable | Purpose |
|---|---|
| `INTUNE_APP_ID` | Existing Intune Win32 app object ID. |
| `SECURE_CONTACTS_MSI_SHA256` | Optional expected SHA-256 value for release pinning. |
| `SECURE_CONTACTS_EXPECTED_SIGNER` | Optional expected Authenticode signer value. |

Keep production values in the protected environment where possible. Do not commit certificates, private keys, passwords, tokens, or tenant-specific values.

The workflow currently attaches `intune-production` to the publishing job. Configure the environment so validation-only runs are permitted by your policy, or split the workflow job and environment boundary if your approval policy requires validation to run without production approval.

## Run modes

Start the workflow from **Actions** -> **Publish Secure Contacts to Intune** -> **Run workflow**.

### Validation only

```text
publish: false
whatIf: false
```

The publisher downloads and validates the latest eligible MSI, creates the `.intunewin` package, and uploads audit artifacts. It does not authenticate to Graph or modify Intune.

### Read-only Intune decision

```text
publish: true
whatIf: true
```

The publisher authenticates, selects the target app, and reports the create/update action without writing the Intune change.

### Publish

```text
publish: true
whatIf: false
```

The publisher validates the release and submits the create/update request to Intune. Require the protected environment approval before using this mode.

The `whatIf` input is intended to be used together with `publish`; setting only `whatIf` does not enable a Graph query.

## Security and artifacts

The workflow imports the certificate into the runner's current-user certificate store only for Graph-enabled runs, deletes the temporary PFX, and removes the imported certificate in an unconditional cleanup step. The shared publisher writes a non-secret manifest containing release, checksum, signer, MSI, package, target, and decision details. Review and retain the uploaded artifact with the deployment record.

For the publisher parameters, manual certificate examples, target selection rules, and failure behavior, see [README.Intune-Publisher-Win.md](README.Intune-Publisher-Win.md). For the broader update decision, see [README.Intune-Update-Options-Win.md](README.Intune-Update-Options-Win.md).

# Secure Contacts - GitHub Actions macOS Intune Pipeline

This guide explains how to operate the full automatic Graph publishing path with GitHub Actions. It is an implementation of path 3 in [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md), not a separate update path.

The workflow is [gh-publish-sca-intune-macos.yml](../.github/workflows/gh-publish-sca-intune-macos.yml). It reuses the shared package validator and Graph publisher; it does not contain a second updater or Graph implementation.

GitHub only discovers Actions workflows from the root `.github/workflows` directory. If you copy this template into an organization-owned repository, preserve that directory and place the workflow file at `.github/workflows/gh-publish-sca-intune-macos.yml`.

## What the workflow does

The manually triggered workflow:

1. Runs on a GitHub-hosted `macos-latest` runner.
2. Runs the shared sync script, which downloads the latest stable ARM64 PKG and matching SHA256 file and validates it.
4. Publishes the validated package and non-secret manifests as workflow artifacts.
5. Runs the publish job only when `publish` is enabled and validation succeeds.
6. Applies the protected `intune-production` environment approval immediately before Graph publishing.
7. Removes temporary certificate files after each job, including failed jobs.

The workflow updates an existing Intune macOS app (PKG) object. It does not create app objects, modify assignments, remove the application, or promote devices automatically.

## Prerequisites

- A GitHub repository with Actions enabled and permission to run the workflow.
- Access to GitHub-hosted `macos-latest`, or an approved self-hosted Mac substituted by your organization.
- An existing Secure Contacts Intune macOS app (PKG) object.
- An Entra application with administrator-consented Microsoft Graph application permission `DeviceManagementApps.ReadWrite.All`.
- An organization-managed certificate containing the private key required by Azure CLI, or an approved OIDC/workload identity design.
- A GitHub environment named `intune-production` with required reviewers or other protection rules.

Apple package validation must run on macOS. A Windows or Linux runner cannot replace the macOS runner for `pkgutil`, `spctl`, package metadata, and ARM64 validation.

## Configure GitHub Actions

1. Open the repository's **Settings** -> **Environments** and create `intune-production`.
2. Add required reviewers and any branch, deployment, or wait timer rules required by your change policy.
3. Add the following repository or environment secrets:

| Secret | Purpose |
|---|---|
| `INTUNE_TENANT_ID` | Entra tenant ID used for Graph authentication. |
| `INTUNE_CLIENT_ID` | Entra publishing application or service principal ID. |
| `INTUNE_CERTIFICATE_BASE64` | Base64-encoded PFX/P12 or PEM certificate containing the private key. |
| `INTUNE_CERTIFICATE_PASSWORD` | Password for the protected certificate; use an empty protected value only when appropriate. |

4. Add this repository or environment variable:

| Variable | Purpose |
|---|---|
| `INTUNE_MACOS_APP_ID` | Existing Secure Contacts macOS PKG app object ID in Intune. |

Keep production credentials in the protected environment when possible. The workflow uses `secrets.INTUNE_*` for secrets and `vars.INTUNE_MACOS_APP_ID` for the non-secret app ID. Do not commit credential values, certificates, private keys, tokens, or tenant-specific configuration.

The sync script expects the official release assets and checks the stable tag and exact filenames. Do not replace those checks with arbitrary tags or URLs.

## Entra and certificate setup

Create and manage the Entra application in your own tenant:

1. Register an application for the publishing workload.
2. Add Microsoft Graph **Application** permission `DeviceManagementApps.ReadWrite.All`.
3. Obtain administrator consent.
4. Issue and rotate an organization-managed certificate with a private key.
5. Store the certificate as `INTUNE_CERTIFICATE_BASE64` and its password as `INTUNE_CERTIFICATE_PASSWORD` in protected GitHub Actions secrets.
6. Set `INTUNE_MACOS_APP_ID` to the existing Intune macOS app object ID.

The shared publisher obtains the Graph token through Azure CLI. Workload identity federation or OIDC is preferred where your GitHub security policy supports it; adapt the authentication boundary without changing the package validator or Graph publishing contract.

## Run modes

Start the workflow from **Actions** -> **Publish Secure Contacts macOS to Intune** -> **Run workflow**.

### Validation only

Set:

```text
publish: false
whatIf: false
```

The workflow downloads and validates the package, then publishes non-secret validation artifacts. It does not call Graph and does not require publishing credentials.

### Read-only Graph decision

Set:

```text
publish: false
whatIf: true
```

The workflow validates the package and runs the shared publisher's read-only Graph decision. Review the validation and decision manifests before publishing.

### Publish to Intune

Set:

```text
publish: true
whatIf: false
```

The validation job must succeed. The publish job then waits for the protected `intune-production` environment approval and invokes `Sync-SecureContactsToIntune.sh --publish`.

The `whatIf` input is intended for a read-only Graph decision. Do not use it as a substitute for the protected production approval.

## Artifacts, rollback, and troubleshooting

The validation job retains the exact downloaded PKG, checksum, validation manifest, and decision manifest for 14 days by default. The publish job retains its audit output separately for 14 days. Change the retention period to match your organization's policy, and do not retain secrets or private keys as artifacts.

For rollback, retain a previously validated package and its checksum. Stop or narrow the current assignment, test the retained package on a pilot Mac, and obtain the normal rollback approval before publishing it. The workflow does not automatically downgrade, alter assignments, or delete old content.

| Problem | Check |
|---|---|
| Workflow cannot use Apple tools | Confirm the job uses `macos-latest` or an approved self-hosted Mac. |
| Environment approval is missing | Confirm `publish` is `true`, the environment is named exactly `intune-production`, and protection rules have required reviewers. |
| Certificate authentication fails | Check the base64 encoding, private key, password, tenant/client IDs, certificate validity, Azure CLI, and Graph administrator consent. |
| App publishing is rejected | Confirm `INTUNE_MACOS_APP_ID` identifies an existing Secure Contacts macOS PKG app. |
| Validation fails | Investigate the release tag, package/checksum pair, signer, Gatekeeper result, bundle ID, version, architecture, and artifact count. |
| Publish job does not start | Confirm validation completed successfully and the workflow input `publish` is enabled. |

For the shared validation rules, Graph `/beta` behavior, permissions, approval policy, and rollback requirements, see [README.Intune-Update-Options-MacOS.md](README.Intune-Update-Options-MacOS.md).

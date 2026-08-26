# Script-Assisted Intune Updates

Run the PowerShell or Bash scripts in this folder on an administrator workstation to automate release resolution, package validation, metadata comparison, and updates to existing Microsoft Intune apps.

This guide covers direct script execution only. It does not require GitHub Actions or Azure DevOps, but the operator must provide the local tools, credentials, certificate material, and cleanup.

## Scripts

- [Windows update script](Sync-SecureContactsToIntune.ps1)
- [macOS update script](Sync-SecureContactsToIntune.sh)
- [macOS package validator](Validate-SecureContactsPackage.sh)

All direct script operations are update-only. The target Intune app must already exist and be configured manually, including reliable device-side detection rules. Follow the [Manual Intune App Creation guide](../README.Intune-Manual-App-Setup.md) for the initial app setup and pilot procedure. Windows publish replaces the existing MSI detection rule when the MSI ProductCode changes, preserves unrelated rules, and never appends a second MSI rule. Apps without exactly one existing MSI rule fail closed.

## How the flow works

1. Resolve a published release from `Provectus-Software-GmbH/SCA_Desktop_Releases`.
2. In publish or What-If mode, compare the release version with the selected existing Intune app before downloading a package.
3. Download and validate the installer when a real update requires package validation. Windows What-If also validates the candidate MSI; macOS What-If uses release and existing-app metadata only.
4. Update the existing Intune app when the release is newer.
5. Write validation and decision manifests to the output directory.

Equal or older releases produce `NoUpdateRequired` and exit successfully. What-If performs the release and Intune version lookup, writes a decision manifest, and does not download, package, upload, or change Intune.

## Operating modes

- **Validation-only:** Download the selected release, validate its checksum and package identity, and write audit artifacts. No Intune credentials are required.
- **Publish:** Compare versions first, then validate and update the existing app only when the release is newer.
- **What-If:** Preview the publish decision using release and existing-app metadata, without downloading, packaging, uploading, or changing Intune. What-If implies publish and therefore requires Intune authentication and an existing app ID.
- **macOS cleanup:** List abandoned uncommitted content versions for the selected existing app. Add `--apply` only when those versions should be deleted.

## Windows

### Prerequisites

Run on Windows PowerShell or PowerShell 7 with access to the `IntuneWin32App` PowerShell module version `1.5.0`. The script installs the pinned module version when needed.

Before publishing, configure the existing Windows app with exactly one MSI detection rule and verify that it identifies the installed Secure Contacts MSI by its ProductCode. During publish, the script replaces that MSI rule when ProductCode changes, preserves unrelated rules, and updates the install and uninstall commands to match the current MSI. What-If reports the planned ProductCode replacement without writing.

For validation-only, GitHub access and the local PowerShell runtime are sufficient. Publishing and What-If also require:

- Microsoft Entra tenant ID and App Registration client ID.
- An existing Windows Intune app ID.
- A certificate registered on the App Registration, with a private key available in the selected certificate store, or a PFX supplied through the script's certificate parameters.
- Microsoft Graph `DeviceManagementApps.ReadWrite.All` application permission with admin consent.

### Validation

From the repository root:

```powershell
.\script-assisted\Sync-SecureContactsToIntune.ps1 `
	-GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases'
```

Select an exact release with `-ReleaseTag` and, when necessary, an exact MSI with `-MsiAssetName`:

```powershell
.\script-assisted\Sync-SecureContactsToIntune.ps1 `
	-GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
	-ReleaseTag 'v0.8.18' `
	-MsiAssetName 'SecureContacts-0.8.18.msi'
```

### Publish or What-If with a certificate thumbprint

The certificate must already be present in `CurrentUser\My` or another store selected with `-CertificateStoreLocation`:

```powershell
.\script-assisted\Sync-SecureContactsToIntune.ps1 `
	-GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
	-TenantId $env:INTUNE_TENANT_ID `
	-ClientId $env:INTUNE_CLIENT_ID `
	-CertificateThumbprint $env:INTUNE_CERTIFICATE_THUMBPRINT `
	-AppId $env:INTUNE_APP_ID `
	-Publish
```

Add `-WhatIf` to preview the release decision and validate a newer candidate MSI without changing Intune:

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

For a PFX, provide `-CertificatePath` and a `SecureString` through `-CertificatePassword`. Do not put certificate passwords in command history. The script can import the PFX for the run; direct users remain responsible for protecting and removing the local certificate material afterward.

## macOS

### Prerequisites

Run on macOS with the Apple package tools and command-line utilities used by the selected mode:

- Validation: `curl`, `jq`, `shasum`, `pkgutil`, `spctl`, `file`, `plutil`, and `PlistBuddy`.
- Publish: the validation tools plus `openssl`, `xxd`, `dd`, `curl`, `jq`, and Azure CLI (`az`) when certificate authentication is used.
- What-If: `curl`, `jq`, and the tools required by the selected authentication method. What-If does not download or validate a PKG.

Before publishing, configure the existing macOS app's Intune detection rules and verify that they identify `de.provectus.SecureContactsDesktop` and the installed bundle version. The script validates bundle metadata and updates package contents, but it does not create or change the app's detection rules.

The macOS sync script calls [Validate-SecureContactsPackage.sh](Validate-SecureContactsPackage.sh) during package validation. The release repository must be reachable through GitHub. Set `SECURE_CONTACTS_GITHUB_TOKEN` only when authenticated access is required, such as for a private release repository or GitHub API rate-limit protection.

### Validation

From the repository root:

```bash
./script-assisted/Sync-SecureContactsToIntune.sh \
	--github-repo Provectus-Software-GmbH/SCA_Desktop_Releases
```

Select an exact release or PKG asset when needed:

```bash
./script-assisted/Sync-SecureContactsToIntune.sh \
	--github-repo Provectus-Software-GmbH/SCA_Desktop_Releases \
	--release-tag v0.8.18 \
	--pkg-asset-name SecureContacts-0.8.18-arm64.pkg
```

### Publish or What-If with a certificate

Before direct macOS publishing, prepare the authentication environment. The certificate password must be stored in a protected file rather than passed as a command argument:

```bash
export INTUNE_TENANT_ID='tenant-guid'
export INTUNE_CLIENT_ID='app-registration-guid'
export INTUNE_APP_ID='existing-macos-intune-app-guid'
export INTUNE_CERTIFICATE_PATH="$HOME/.config/secure-contacts/intune-auth.p12"
export INTUNE_CERTIFICATE_PASSWORD_FILE="$HOME/.config/secure-contacts/intune-auth.password"
export INTUNE_AUTH_METHOD=certificate
chmod 600 "$INTUNE_CERTIFICATE_PATH" "$INTUNE_CERTIFICATE_PASSWORD_FILE"
```

The certificate must be registered on the App Registration, and the App Registration requires Microsoft Graph `DeviceManagementApps.ReadWrite.All` application permission with admin consent. Run a read-only release decision preview first; What-If compares the candidate release with the existing app without downloading or validating a PKG:

```bash
./script-assisted/Sync-SecureContactsToIntune.sh \
	--github-repo Provectus-Software-GmbH/SCA_Desktop_Releases \
	--app-id "$INTUNE_APP_ID" \
	--publish \
	--what-if
```

Run the real update only after reviewing the decision manifest:

```bash
./script-assisted/Sync-SecureContactsToIntune.sh \
	--github-repo Provectus-Software-GmbH/SCA_Desktop_Releases \
	--app-id "$INTUNE_APP_ID" \
	--publish
```

The script supports `GRAPH_ACCESS_TOKEN` with `INTUNE_AUTH_METHOD=token` for short-lived testing. Do not use long-lived tokens in command history or production automation.

### Existing package and cleanup operations

Use `--use-existing-package` when the output directory already contains a package and validation artifacts that should be used for publishing:

```bash
./script-assisted/Sync-SecureContactsToIntune.sh \
	--github-repo Provectus-Software-GmbH/SCA_Desktop_Releases \
	--app-id "$INTUNE_APP_ID" \
	--use-existing-package \
	--publish
```

List abandoned uncommitted content versions without deleting anything:

```bash
./script-assisted/Sync-SecureContactsToIntune.sh \
	--github-repo Provectus-Software-GmbH/SCA_Desktop_Releases \
	--app-id "$INTUNE_APP_ID" \
	--cleanup
```

Add `--apply` only to delete the listed abandoned versions. Cleanup cannot be combined with `--publish` or `--what-if`.

## Authentication and secrets

`INTUNE_TENANT_ID` is the Microsoft Entra Directory (tenant) ID. `INTUNE_CLIENT_ID` is the Application (client) ID of the App Registration used for Microsoft Graph authentication. Both values must belong to the tenant and App Registration configured for this integration.

Keep certificate passwords, private keys, client secrets, access tokens, and GitHub tokens out of source control and command history. Use the least-privileged GitHub token possible: a fine-grained token with **Contents: Read-only** access to the release repository. The scripts do not write the GitHub token to manifests or status messages.

## Output artifacts

The scripts write output beneath their selected output directory, including validation manifests, decision manifests, downloaded installers, and generated Windows `.intunewin` packages when package work occurs. Use the decision manifest to review the candidate release, existing Intune version, selected app ID, and resulting decision.

Direct execution does not provide pipeline artifact storage or automatic cleanup. Protect output files and remove downloaded packages and temporary certificate material according to your local security policy.

## Script help

```powershell
Get-Help .\script-assisted\Sync-SecureContactsToIntune.ps1 -Full
```

```bash
./script-assisted/Sync-SecureContactsToIntune.sh --help
./script-assisted/Validate-SecureContactsPackage.sh --help
```

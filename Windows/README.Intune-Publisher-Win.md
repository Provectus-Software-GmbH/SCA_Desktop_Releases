# Secure Contacts Intune Publisher (Windows)

`Scripts/Sync-SecureContactsToIntune.ps1` stages a Windows MSI from the latest eligible GitHub release, or from an explicitly selected release tag, validates it, creates an `.intunewin` package, and optionally updates Microsoft Intune.

For the three Windows update choices, see [README.Intune-Update-Options-Win.md](README.Intune-Update-Options-Win.md). CI-specific setup is documented in [README.Intune-GitHub-Actions.md](README.Intune-GitHub-Actions.md) and [README.Intune-Azure-DevOps.md](README.Intune-Azure-DevOps.md).

## Safety model

The script performs validation and packaging by default. It does not authenticate to Graph or change Intune unless `-Publish` is supplied. `-WhatIf` can be combined with `-Publish` to exercise target selection without writing the app change.

Validation fails closed when:

- The GitHub repository is not in `owner/repository` form, or the latest release is missing, draft, or prerelease.
- There is not exactly one MSI asset, unless `-MsiAssetName` selects one exact asset within the selected release.
- The release has no SHA-256 digest or matching `.sha256` asset.
- The downloaded file does not match the release checksum.
- Authenticode signature status is not `Valid`.
- MSI ProductCode, ProductName, or ProductVersion cannot be read.
- The release tag is not exactly `vMAJOR.MINOR.PATCH`, the MSI filename does not match that normalized version, or the first three numeric components of MSI `ProductVersion` do not match it.
- More than one Intune app matches the display name. Use `-AppId` for an existing app.
- An existing Intune app has no usable three-part `displayVersion`; the script refuses to publish without a safe comparison.

The temporary workspace uses a unique GUID-based directory and is removed in `finally`. A non-secret `manifest.json` is written during staging, update, create, or no-op runs and includes release, normalized version, checksum, signer, MSI identity, package, target version, decision, final action, and module-version details. Client secrets are never written to the manifest or output.

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7 on Windows.
- An Entra app with `DeviceManagementApps.ReadWrite.All` application permission and admin consent.
- `IntuneWin32App` PowerShell module version `1.5.0` or newer. The script accepts newer versions, while installing exactly `1.5.0` is recommended for reproducible runs.
- A signed x64 MSI with a GitHub release SHA-256 digest or adjacent `<asset>.sha256` asset. Windows Installer may report `ProductVersion` with four components, such as `0.8.18.0`.
- A Windows certificate with a private key, or a client secret for testing only.
- `TenantId` and `ClientId` are required only when publishing to Intune.

Install the pinned module explicitly before running the publisher:

```powershell
Install-Module -Name IntuneWin32App -RequiredVersion 1.5.0 -Scope CurrentUser
```

## Staging and validation

Client-secret authentication is not needed for staging. The following downloads and validates the latest release, packages it, writes the manifest, and exits without contacting Intune:

```powershell
.\Scripts\Sync-SecureContactsToIntune.ps1 `
  -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases'
```

`TenantId` and `ClientId` are not required for this validation-only command. Graph authentication and Intune access begin only when `-Publish` is supplied.

`ExpectedSha256` and `ExpectedSigner` are optional hardening parameters. The script always requires a SHA-256 digest from the GitHub release metadata or a matching `.sha256` asset, and always requires a valid Authenticode signature. Use `ExpectedSha256` to pin the release to a checksum known in advance, and use `ExpectedSigner` to restrict the accepted signer certificate.

## Progress output

The publisher writes concise `[Secure Contacts]` milestone messages for module checks, GitHub release resolution, Intune target selection, MSI download and validation, packaging, artifact retention, and create/update requests. These messages contain operational identifiers and paths only; credentials and access tokens are not intentionally written by the script.

Packaging and Intune processing can take several minutes. During the Intune wait, the script reports the current processing state at most every 45 seconds and continues polling every 15 seconds until the configured timeout. A successful run reports whether it validated only, skipped because the Intune version was already current, or completed an update/create request. With `-Publish -WhatIf`, the target action is shown but the final message confirms that no Intune write was performed.

CI logs may also contain output produced by the `IntuneWin32App` module itself. Treat the publisher's `[Secure Contacts]` lines as the stage indicators, and keep verbose or debug tracing disabled unless troubleshooting in a controlled environment.

To validate or publish a specific release, supply its exact tag. The asset name remains optional when that release contains one matching MSI:

```powershell
.\Scripts\Sync-SecureContactsToIntune.ps1 `
  -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
  -ReleaseTag 'v0.8.18' `
  -ExpectedSigner 'Provectus Software GmbH'
```

## Release-version gating

The publisher accepts only release tags in the form `vMAJOR.MINOR.PATCH`, such as `v0.8.12`, `v0.9.1`, or `v1.3.11`. The leading `v` is removed for comparison, and versions are compared numerically, so `1.3.11` is newer than `1.3.9`.

In validation-only mode, the script downloads and validates the latest release because there is no Intune query. In publish mode, it authenticates and resolves the target app before downloading the MSI:

- If the target `displayVersion` is equal to or newer than GitHub, the run exits successfully without downloading, packaging, or publishing.
- If GitHub is newer, the MSI is downloaded, validated, packaged, and used to update the existing app.
- If no target app exists, the MSI is downloaded, validated, packaged, and used to create the app.

The expected asset name is `SecureContacts-MAJOR.MINOR.PATCH.msi`. The MSI `ProductVersion` is normalized to its first three numeric components before comparison, so release tag `v0.8.18` accepts MSI version `0.8.18.0` (and other four-part values beginning with `0.8.18`). A value such as `0.8.17.0` is rejected. `-MsiAssetName` can select an asset within the chosen release, but it cannot select a release or bypass this consistency check.

## Publishing with a client secret for testing

The client-secret path remains available for easy testing. Keep the value out of source control and shell history where possible:

For manual administration, the following command uses the default display name to find the existing Intune app. It is safe when exactly one app is named `Secure Contacts Desktop Enterprise`:

```powershell
.\Scripts\Sync-SecureContactsToIntune.ps1 `
  -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
  -TenantId $tenantId `
  -ClientId $clientId `
  -ClientSecret $secretText `
  -Publish
```

If no app matches that display name, the script prepares a new Intune app. If more than one app matches, it stops and requires `-AppId`; it never guesses which duplicate to update.

```powershell
$secret = Read-Host 'Client secret' -AsSecureString
$secretText = [Net.NetworkCredential]::new('', $secret).Password
try {
  .\Scripts\Sync-SecureContactsToIntune.ps1 `
    -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
    -TenantId $tenantId -ClientId $clientId -ClientSecret $secretText `
    -AppId '00000000-0000-0000-0000-000000000000' -Publish
}
finally {
  $secretText = $null
}
```

The script emits a warning for this mode because client secrets are intended for testing, not production automation.

For automation, keep the secret in a protected environment variable and pass its variable name. The script resolves the value only when it authenticates:

```powershell
.\Scripts\Sync-SecureContactsToIntune.ps1 `
  -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
  -TenantId $env:INTUNE_TENANT_ID -ClientId $env:INTUNE_CLIENT_ID `
  -ClientSecretEnvironmentVariable 'INTUNE_CLIENT_SECRET' `
  -AppId $env:INTUNE_APP_ID -Publish
```

## Publishing with a certificate for production

Use a certificate with the private key installed in the selected Windows certificate store. The certificate thumbprint must be 40 hexadecimal characters:

```powershell
.\Scripts\Sync-SecureContactsToIntune.ps1 `
  -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
  -TenantId $tenantId -ClientId $clientId `
  -CertificateThumbprint '0123456789ABCDEF0123456789ABCDEF01234567' `
  -CertificateStoreLocation 'CurrentUser\My' `
  -AppId '00000000-0000-0000-0000-000000000000' -Publish
```

The script loads the certificate from `CertificateStoreLocation` and passes the certificate object to the module's `ClientCert` parameter. The certificate must contain a private key and must not be expired.

For a CI runner, the script can import a PFX file into the current-user certificate store and remove it during its own cleanup:

```powershell
$certificatePassword = ConvertTo-SecureString $env:INTUNE_CERTIFICATE_PASSWORD -AsPlainText -Force
.\Scripts\Sync-SecureContactsToIntune.ps1 `
  -GitHubRepo 'Provectus-Software-GmbH/SCA_Desktop_Releases' `
  -TenantId $env:INTUNE_TENANT_ID -ClientId $env:INTUNE_CLIENT_ID `
  -CertificatePath $env:INTUNE_CERTIFICATE_PATH `
  -CertificatePassword $certificatePassword `
  -AppId $env:INTUNE_APP_ID -Publish
```

The PFX password must be supplied as a protected pipeline secret. The script does not write the password or PFX contents to the manifest. When a pipeline imports the PFX itself and passes only `-CertificateThumbprint`, the pipeline must remove the certificate in an `always()`/`condition: always()` cleanup step.

## Target selection and review

- For manual administration, omitting `-AppId` is supported: the script retrieves Win32 apps and matches the configured display name locally.
- For CI/CD and repeatable production publishing, prefer `-AppId` when updating an existing app. This is the GUID of the Intune Win32 app record, not the MSI `ProductCode`.
- The `-AppId` value can be taken from the app's `id` property returned by `Get-IntuneWin32App` or from the Intune admin center.
- Without `-AppId`, the script retrieves Win32 apps and matches `$AppName` locally; it fails if more than one app matches.
- With `-AppId`, a missing match fails closed rather than creating a different app.
- If there is no name match, it prepares a new app using MSI detection and an x64 Windows 10 version 1909 requirement.
- If duplicate apps already exist, the script stops and requires `-AppId`; it will not create another duplicate.
- Use `-Publish -WhatIf` to confirm the selected create/update action without writing it.

The script submits the Intune request but does not assign the app to groups. Confirm that Intune has finished processing the content before assigning it and retain the generated manifest with the deployment record.

## CI templates

- GitHub Actions: `.github/workflows/gh-publish-sca-intune-win.yml`
- Azure DevOps: `Windows/.azure-pipelines/azure-publish-sca-intune-win.yml`

Both templates use a Windows runner and install the pinned module. They support these modes:

- Validation only: `publish: false`. The workflow packages and audits the MSI without authenticating to Graph; certificate secrets are not imported or required.
- Review an Intune action: `publish: true`, `whatIf: true`. The workflow authenticates, selects the target, and reports the create/update action without writing to Intune.
- Publish: `publish: true`, `whatIf: false`. The workflow authenticates and submits the create/update request.

The `whatIf` input is intended to be used together with `publish`; it does not make a validation-only run query Intune. For the two Graph-enabled modes, configure these protected secrets/variables in the CI platform: `INTUNE_TENANT_ID`, `INTUNE_CLIENT_ID`, `INTUNE_CERTIFICATE_BASE64`, and `INTUNE_CERTIFICATE_PASSWORD`. Configure the app ID and expected artifact values as protected variables. Protect the `intune-production` GitHub environment or the corresponding Azure DevOps pipeline approval before enabling publication.

OIDC/workload-identity authentication is not implemented by this script. CI therefore needs either the protected PFX flow shown in the templates or the protected client-secret environment-variable flow.

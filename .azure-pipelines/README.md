## Secure Contacts Intune Pipelines

This `.azure-pipelines` folder is a self-contained Azure DevOps bundle. Copy the complete folder, including both YAML files and all three scripts, into an administrator-owned Azure DevOps repository. The pipelines recursively locate their scripts, so the folder can be placed at the repository root or in a subfolder. The checkout used by an Azure pipeline must contain one copy of each discovered script; keeping the same scripts in `script-assisted`, `.azure-pipelines`, and `.github/workflows` in this source repository is intentional because each automation entry point is copied independently.

The pipelines support validation, publishing, What-If preview, and macOS content-version cleanup:

- **Validation-only (default):** resolve the selected GitHub release, download the installer, validate its checksum and identity, and write package audit artifacts. This mode does not require Intune or Graph credentials.
- **Publish:** query the existing Intune app before downloading. The package is downloaded, validated, and published only when the GitHub release is newer. Equal or older versions produce `NoUpdateRequired` and exit successfully.
- **What-if:** use the read-only `-WhatIf`/`--what-if` option to preview publishing. What-if implies publish, so it compares versions, downloads and validates the candidate MSI when an update is needed, and writes a decision manifest without packaging, uploading, or changing Intune. It still requires the target app and Intune authentication.

Publishing is update-only. The supplied Windows `AppId` or macOS app ID must identify an app that was created and configured manually in Intune, including tested device-side detection rules. Follow the [Manual Intune App Creation guide](../README.Intune-Manual-App-Setup.md) for the initial app setup and pilot procedure. Windows publish replaces the existing MSI detection rule when the MSI ProductCode changes, preserves unrelated rules, and never appends a second MSI rule. Apps without exactly one existing MSI rule fail closed.

### Microsoft Graph / Intune authentication

Both supplied Azure DevOps pipelines use certificate-based Microsoft Graph authentication for publish and What-If operations. `INTUNE_TENANT_ID` identifies the Microsoft Entra tenant (Directory (tenant) ID), while `INTUNE_CLIENT_ID` identifies the App Registration used by the scripts (Application (client) ID). The certificate used by either pipeline must be registered on that App Registration, and the application must have Microsoft Graph `DeviceManagementApps.ReadWrite.All` application permission with admin consent. Both scripts stop if authentication fails.

### Windows

Run the PowerShell script from the repository root:

```powershell
.\.azure-pipelines\Sync-SecureContactsToIntune.ps1 -GitHubRepo 'owner/repository'
.\.azure-pipelines\Sync-SecureContactsToIntune.ps1 -GitHubRepo 'owner/repository' -TenantId $tenantId -ClientId $clientId -AppId $appId -CertificateThumbprint $thumbprint -Publish
.\.azure-pipelines\Sync-SecureContactsToIntune.ps1 -GitHubRepo 'owner/repository' -TenantId $tenantId -ClientId $clientId -AppId $appId -CertificateThumbprint $thumbprint -Publish -WhatIf
```

`-ReleaseTag` selects an exact `vMAJOR.MINOR.PATCH` release. `-MsiAssetName` selects an exact MSI when a release contains multiple MSI assets. The script uses the pinned `IntuneWin32App` PowerShell module version `1.5.0` for packaging and updating the existing app. `-WhatIf` implies `-Publish`, so an existing `AppId` and Graph credentials are required for the preview.

The Windows pipeline imports the protected PFX into the agent's CurrentUser certificate store for the run.

The Windows pipeline recursively locates `Sync-SecureContactsToIntune.ps1`, allowing this bundle to run from the repository root or any repository subfolder. It publishes audit artifacts on both successful and failed runs when the artifact directory exists.

### macOS

Run the shell script from the repository root with the repository and optional release or asset settings:

```bash
./.azure-pipelines/Sync-SecureContactsToIntune.sh --github-repo owner/repository
./.azure-pipelines/Sync-SecureContactsToIntune.sh --github-repo owner/repository --app-id "$INTUNE_MACOS_APP_ID" --publish
./.azure-pipelines/Sync-SecureContactsToIntune.sh --github-repo owner/repository --app-id "$INTUNE_MACOS_APP_ID" --publish --what-if
```

`--release-tag` selects an exact release, `--pkg-asset-name` selects an exact PKG, and `--use-existing-package` makes publish consume an already validated pipeline artifact. macOS publish and What-If require Graph authentication settings; validation-only does not. The supplied macOS pipeline uses Azure CLI certificate authentication, unlocking the protected certificate only for the run and storing temporary certificate material in the agent temporary directory. Cleanup steps remove those files. For short-lived local testing, the script also supports `GRAPH_ACCESS_TOKEN` with `INTUNE_AUTH_METHOD=token`.

Use `--cleanup` to list abandoned uncommitted content versions for the selected existing macOS app. Add `--apply` to delete the listed versions. Cleanup is read-only unless `--apply` is supplied and cannot be combined with `--publish` or `--what-if`.

### GitHub authentication

Both scripts use GitHub to resolve Secure Contacts releases and download their installer assets. Set the optional `SECURE_CONTACTS_GITHUB_TOKEN` environment variable when the Secure Contacts release repository is private or when authenticated requests are needed to avoid GitHub API rate limits on hosted CI agents. It may remain unset when the release repository is public and the anonymous API limit is sufficient.

The token must be customer-owned and stored as a secret Azure DevOps pipeline or variable-group variable, then exposed only through the script step's environment. Use the least privilege available: a fine-grained repository token with **Contents: Read-only** for the release repository. GitHub organization SSO approval may also be required. Rotate or revoke the token according to the customer's credential policy.

The scripts send the token only to GitHub requests and never write it to URLs, manifests, or status messages. Release asset redirects are restricted to HTTPS on macOS.

### Artifacts

Validation runs write a validation manifest and the generated Windows `.intunewin` or downloaded macOS PKG artifacts. Publish What-If and successful no-update runs write a decision manifest containing the candidate release, existing Intune version, target app ID, decision, and timestamp. What-If validates the candidate MSI but does not create package artifacts or modify Intune.

### Azure DevOps configuration

The pipelines are manually triggered (`trigger: none`) and expose `publish` and `whatIf` parameters. Store all certificate, Entra, Intune app ID, integrity, signer, and GitHub token values as pipeline or variable-group variables. Keep secrets marked secret and do not place secret values directly in YAML. For the Secure Contacts release source, configure `SECURE_CONTACTS_GITHUB_TOKEN` when authenticated GitHub access is required; see [GitHub authentication](#github-authentication).

For both pipelines, configure `INTUNE_TENANT_ID` with the Microsoft Entra Directory (tenant) ID and `INTUNE_CLIENT_ID` with the App Registration Application (client) ID. Configure the certificate and password values used by the corresponding pipeline. The Windows pipeline uses `INTUNE_CERTIFICATE_BASE64` and `INTUNE_CERTIFICATE_PASSWORD`; the macOS pipeline uses the same values to create its temporary certificate files.

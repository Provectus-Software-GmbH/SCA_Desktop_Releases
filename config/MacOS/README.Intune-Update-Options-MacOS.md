# Secure Contacts macOS Intune Update Options

This repository supports exactly three macOS update paths, in this order:

1. **Manual:** download, verify, prepare the validated PKG, and upload it to Intune.
2. **Semi-automated staging:** the sync script downloads and verifies the PKG and prepares it for manual Intune upload.
3. **Full automatic Graph publishing:** the sync script downloads, verifies, and publishes the PKG to an existing Intune app through Microsoft Graph.

The semi-automated and full paths run on an administrator Mac, an Azure DevOps macOS agent, or a GitHub Actions macOS runner. The manual path uses the Intune portal. The uninstall guide and uninstall script are separate and are not part of these update paths.

## 1. Manual

Use this path when an administrator wants to control every step in the portal.

1. Open the [Secure Contacts Releases page](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases) and select an approved stable release.
2. Download the matching files:

   ```text
   SecureContacts-<version>-arm64.pkg
   SecureContacts-<version>-arm64.pkg.sha256
   ```

3. On a Mac, place both files in `./artifacts` and run the validator:

   ```bash
   ./MacOS/Scripts/Validate-SecureContactsPackage.sh \
      --output ./artifacts \
      --manifest-output ./artifacts/validation-manifest.json
   ```

   The validator checks the checksum, Developer ID signer, Gatekeeper assessment, bundle ID, version, and ARM64 executable.
4. Upload the exact validated `SecureContacts-<version>-arm64.pkg` to the existing Secure Contacts macOS app (PKG) in Intune.
5. Assign it to a pilot group, verify installation and managed preferences, then promote it through the normal deployment rings.

## 2. Semi-automated staging

Use this path when release acquisition and validation should be repeatable while Intune upload and approval remain manual. It requires no Graph credentials.

Run the self-contained sync script on an administrator Mac, Azure DevOps `macOS-latest`, or a GitHub Actions `macos-latest` runner:

```bash
./MacOS/Scripts/Sync-SecureContactsToIntune.sh \
   --output ./artifacts \
   --manifest-output ./artifacts/validation-manifest.json
```

The script resolves the latest stable `vMAJOR.MINOR.PATCH` GitHub release, downloads the exact ARM64 PKG and matching SHA256 file, runs the Graph-free validator, and writes a non-secret validation manifest. It does not authenticate to Graph or modify Intune.

Review the manifest and checksum, retain the exact staged files, and upload the validated PKG manually through the Intune portal. Complete pilot testing and normal approval before broader assignment.

## 3. Full automatic Graph publishing

Use this path when an organization-owned Mac or macOS CI runner should publish to an existing Intune macOS PKG app. The script never creates an app, changes assignments, uninstalls the application, or performs an automatic downgrade.

The safe progression is:

1. Run the staging command above with no Graph variables and no flags.
2. Add the protected Graph variables and run a read-only decision:

   ```bash
   export INTUNE_TENANT_ID='<tenant-id>'
   export INTUNE_CLIENT_ID='<publishing-app-id>'
   export INTUNE_CERTIFICATE_PATH='/secure/path/publishing-certificate.p12'
   export INTUNE_CERTIFICATE_PASSWORD_FILE='/secure/path/publishing-certificate.password'
   export INTUNE_APP_ID='<existing-macOS-PKG-app-id>'

   ./MacOS/Scripts/Sync-SecureContactsToIntune.sh --publish --what-if
   ```

   `--what-if` requires `--publish`; this combination performs no Graph write. Review the decision manifest and validation artifacts.
3. With the same protected variables, run the approved publish:

   ```bash
   ./MacOS/Scripts/Sync-SecureContactsToIntune.sh --publish
   ```

The publisher validates before any Graph write, uploads the exact validated bytes, updates only the explicitly selected existing macOS PKG app, polls processing, and verifies the final identity and version. Keep the approval gate between validation/what-if review and the publish command.

### Required Graph settings

The Entra application must have administrator-consented Microsoft Graph application permission `DeviceManagementApps.ReadWrite.All`. Use an organization-managed certificate through Azure CLI, or set `INTUNE_AUTH_METHOD=token` with a short-lived `GRAPH_ACCESS_TOKEN` only for local testing. Never commit certificates, passwords, tokens, tenant IDs, or app-specific values.

For a password-protected PFX/P12 or encrypted PEM, keep the password in a protected file. The script never accepts the password as a command argument and removes temporary authentication state on exit.

### CI implementations

- [GitHub Actions guide](README.Intune-GitHub-Actions.md) and [workflow](../.github/workflows/gh-publish-sca-intune-macos.yml)
- [Azure DevOps guide](README.Intune-Azure-DevOps.md) and [pipeline](.azure-pipelines/azure-publish-sca-intune-macos.yml)

Both examples run package validation on macOS, retain artifacts, and place the `intune-production` approval before the publish job. They call the same self-contained sync script; the CI definitions do not download release assets separately.

### Cleanup

To preview abandoned uncommitted content versions for the selected existing app:

```bash
./MacOS/Scripts/Sync-SecureContactsToIntune.sh --app-id '<existing-macOS-PKG-app-id>' --cleanup
```

Use `--cleanup --apply` only after reviewing the candidates. Cleanup requires the same Graph authentication settings and does not stage or publish a package.

## Common rules

Use only a stable release with the matching ARM64 PKG and checksum. Reject prereleases, missing or ambiguous assets, signer changes, version mismatches, and downgrades. Retain the approved package and checksum for rollback, test rollback on a pilot Mac, and use normal change approval.

The validator remains Graph-free and can be used independently for the manual path. The sync script is the single download, staging, validation, and optional Graph publishing entry point for the semi-automated and full paths.

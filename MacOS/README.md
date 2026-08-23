# Secure Contacts — macOS Deployment Files

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices.

This folder contains the files IT administrators need to deploy, configure, and manage SCA on macOS devices. Intune application deployment uses the signed PKG, while managed configuration uses a plist-based profile. A separate configuration path covers non-Intune MDM platforms such as Jamf and Kandji.

**Start here:**

1. Deploy the app with [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md).
2. Configure managed preferences with [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md).
3. For optional application removal or complete data cleanup, use [README.Intune-Uninstall.MacOS.md](README.Intune-Uninstall.MacOS.md) and [Scripts/Uninstall-SecureContacts.sh](Scripts/Uninstall-SecureContacts.sh).
4. To compare or operate any of the four macOS update paths, use [README.AutoUpdate-Pipeline-MacOS.md](README.AutoUpdate-Pipeline-MacOS.md).
5. For the optional direct endpoint updater, review [Scripts/Install-SecureContacts.sh](Scripts/Install-SecureContacts.sh) and the updater section in [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md).

## Choose an update path

| Path | Best for | Tradeoff |
|---|---|---|
| Manual GitHub download | Small or infrequent deployments | Repeat the download, validation, and Intune upload for each release |
| Manual AutoPkg staging | Repeatable package acquisition without Graph | Requires AutoPkg; Intune upload and approval remain manual |
| Customer-owned Graph pipeline | Centralized, auditable approval and publishing | Requires customer CI, Graph permissions, credentials, and maintenance |
| Direct endpoint updater | Windows-like client-side update behavior | Less Intune version visibility; depends on shell scheduling, endpoint permissions, GitHub access, and pilot validation |

For the detailed comparison and decision guidance, see [README.AutoUpdate-Pipeline-MacOS.md](README.AutoUpdate-Pipeline-MacOS.md#four-available-paths).

## Files in this folder

| File | Role |
|---|---|
| [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md) | Full Intune configuration guide (plist method + non-Intune MDM) |
| [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md) | Intune PKG app deployment, verification, detection, assignment, update, and rollback guide |
| [README.Intune-Uninstall.MacOS.md](README.Intune-Uninstall.MacOS.md) | Optional macOS application-only uninstall or complete per-user data purge guide |
| [README.AutoUpdate-Pipeline-MacOS.md](README.AutoUpdate-Pipeline-MacOS.md) | Four macOS update paths: manual GitHub, manual AutoPkg, customer-owned Graph publishing, and direct endpoint updating |
| [Scripts/Install-SecureContacts.sh](Scripts/Install-SecureContacts.sh) | Optional customer-owned endpoint updater; downloads, validates, and installs a newer ARM64 PKG |
| [Scripts/Uninstall-SecureContacts.sh](Scripts/Uninstall-SecureContacts.sh) | Intune macOS Shell script for validated application removal and optional complete data purge |
| [Scripts/Invoke-SecureContactsAutoUpdate.sh](Scripts/Invoke-SecureContactsAutoUpdate.sh) | Graph-free ARM64 PKG staging and validation runner; never writes to Graph |
| [Scripts/Sync-SecureContactsToIntune.sh](Scripts/Sync-SecureContactsToIntune.sh) | Validation orchestration entry point with read-only beta Graph `--what-if` decisioning; publishing remains disabled |
| [plist/de.provectus.SecureContactsDesktop.plist](plist/de.provectus.SecureContactsDesktop.plist) | Blank plist config template for production use |
| [plist/de.provectus.SecureContactsDesktop.plist.demo](plist/de.provectus.SecureContactsDesktop.plist.demo) | Demo plist with sample values (reference only) |
| [plist/secure-contacts-manifest.json](plist/secure-contacts-manifest.json) | Manifest schema reference for non-Intune MDM platforms |
| [de.provectus.securecontacts.download.recipe.yaml](AutoPkg/de.provectus.securecontacts.download.recipe.yaml) | Downloads the latest stable ARM64 package and verifies the Provectus signing chain |
| [de.provectus.securecontacts.intune.recipe.yaml](AutoPkg/de.provectus.securecontacts.intune.recipe.yaml) | Stages the verified package and official SHA256 file for Intune or CI |
| [de.provectus.securecontacts.config.recipe.yaml](AutoPkg/de.provectus.securecontacts.config.recipe.yaml) | Stages the production, demo, and manifest configuration files |

## AutoPkg recipes

The recipes are optional deployment helpers. They require:

- macOS with AutoPkg 2.3 or later
- Network access to GitHub and the GitHub API
- Apple silicon target devices; the package recipe currently selects the published ARM64 `.pkg`
- An existing output directory when `OUTPUT_PATH` is overridden

Run the recipes from a clone of this repository by passing their paths directly, or add the repository to AutoPkg's recipe search path and use their identifiers.

### Download and signature verification

```bash
autopkg run ./MacOS/AutoPkg/de.provectus.securecontacts.download.recipe.yaml
```

The download recipe selects the latest non-prerelease GitHub release marked as latest, downloads `SecureContacts-<version>-arm64.pkg`, and fails unless `pkgutil --check-signature` returns this exact certificate chain:

```text
Developer ID Installer: Provectus Software GmbH (572S9T76X8)
Developer ID Certification Authority
Apple Root CA
```

Do not set `DISABLE_CODE_SIGNATURE_VERIFICATION` in production automation.

### Stage Intune artifacts

Default cache output:

```bash
autopkg run ./MacOS/AutoPkg/de.provectus.securecontacts.intune.recipe.yaml
```

The default output directory is:

```text
~/Library/AutoPkg/Cache/de.provectus.securecontacts.intune/
```

### Run the validation wrapper

The sync entry point provides the planned publisher interface while Graph publishing is being implemented:

```bash
./MacOS/Scripts/Sync-SecureContactsToIntune.sh \
	--output ./artifacts \
	--manifest-output ./artifacts/validation-manifest.json
```

This runs AutoPkg and the full validation runner, then writes a non-secret JSON manifest. It is validation-only by default. `--publish` currently fails closed because the macOS Intune Graph upload contract has not yet been verified. `--what-if` performs a read-only beta Graph lookup and version decision when supplied with an existing app ID and an access token through environment variables; it never uploads, commits, creates, or assigns an app.

Read-only decision check against an existing test app:

```bash
export INTUNE_APP_ID='<existing macOS PKG app GUID>'
export GRAPH_ACCESS_TOKEN='<short-lived test token>'
./MacOS/Scripts/Sync-SecureContactsToIntune.sh \
	--output ./artifacts \
	--skip-recipe \
	--publish \
	--what-if
```

The token must be supplied out-of-band and is never written to a manifest. The beta contract evidence and remaining upload requirements are tracked in [Documentation/Intune-macos-pkg-graph-contract.md](Documentation/Intune-macos-pkg-graph-contract.md).

CI or a custom local directory:

```bash
mkdir -p ./artifacts
autopkg run ./MacOS/AutoPkg/de.provectus.securecontacts.intune.recipe.yaml \
	-k OUTPUT_PATH=./artifacts
```

Expected artifacts:

```text
SecureContacts-<version>-arm64.pkg
SecureContacts-<version>-arm64.pkg.sha256
```

The `.sha256` file is downloaded from the same official GitHub release. The recipe stages it but does not compare it automatically. Verify the package before upload:

```bash
cd ./artifacts
shasum -a 256 -c SecureContacts-<version>-arm64.pkg.sha256
spctl --assess --type install --verbose=4 SecureContacts-<version>-arm64.pkg
```

For the complete manual and optional customer-owned polling workflow, see [README.AutoUpdate-Pipeline-MacOS.md](README.AutoUpdate-Pipeline-MacOS.md). The validation runner is intentionally Graph-free; from the repository root on macOS, make it executable once with `chmod +x ./MacOS/Scripts/Invoke-SecureContactsAutoUpdate.sh`.

The runner stages the latest package with AutoPkg and validates it by default. Use `--skip-recipe` when the output directory already contains the artifacts produced by a separate recipe step.

The signature check enforces publisher identity and package integrity. The SHA256 comparison detects transfer or storage corruption. The `spctl` command separately checks the current Gatekeeper/notarization assessment.

### Stage configuration files

```bash
autopkg run ./MacOS/AutoPkg/de.provectus.securecontacts.config.recipe.yaml
```

The default output directory is:

```text
~/Library/AutoPkg/Cache/de.provectus.securecontacts.config/
```

Use `SecureContacts-config-production.plist` as the editable Intune preference-file fragment. Never deploy `SecureContacts-config-demo.plist`; it contains example values only. Follow [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md) for the supported keys and Intune workflow.

For custom output:

```bash
mkdir -p ./artifacts/config
autopkg run ./MacOS/AutoPkg/de.provectus.securecontacts.config.recipe.yaml \
	-k OUTPUT_PATH=./artifacts/config
```

## Enterprise rollout guidance

Treat recipe output as a deployment candidate, not as automatic production approval. Pin or retain the approved package in your artifact repository, record its version and SHA256 value, test installation and managed preferences on a pilot device group, and promote the same verified bytes through deployment rings. A newly published GitHub release should not bypass your normal change-control process.

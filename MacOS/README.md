# Secure Contacts — macOS Deployment Files

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices.

This folder contains the files IT administrators need to deploy, configure, and manage SCA on macOS devices. Intune application deployment uses the signed PKG, while managed configuration uses a plist-based profile. A separate configuration path covers non-Intune MDM platforms such as Jamf and Kandji.

**Start here:**

1. Deploy the app with [SCA-Intune-Deploy-Manual-MacOS.md](SCA-Intune-Deploy-Manual-MacOS.md).
2. Configure managed preferences with [SCA-Intune-Config-Manual-Mac.md](SCA-Intune-Config-Manual-Mac.md).

## Files in this folder

| File | Role |
|---|---|
| [SCA-Intune-Deploy-Manual-MacOS.md](SCA-Intune-Deploy-Manual-MacOS.md) | Intune PKG app deployment, verification, detection, assignment, update, and rollback guide |
| [SCA-Intune-Config-Manual-Mac.md](SCA-Intune-Config-Manual-Mac.md) | Full Intune configuration guide (plist method + non-Intune MDM) |
| [de.provectus.SecureContactsDesktop.plist](de.provectus.SecureContactsDesktop.plist) | Blank plist config template for production use |
| [de.provectus.SecureContactsDesktop.plist.demo](de.provectus.SecureContactsDesktop.plist.demo) | Demo plist with sample values (reference only) |
| [secure-contacts-manifest.json](secure-contacts-manifest.json) | Manifest schema reference for non-Intune MDM platforms |
| [de.provectus.securecontacts.download.recipe.yaml](de.provectus.securecontacts.download.recipe.yaml) | Downloads the latest stable ARM64 package and verifies the Provectus signing chain |
| [de.provectus.securecontacts.intune.recipe.yaml](de.provectus.securecontacts.intune.recipe.yaml) | Stages the verified package and official SHA256 file for Intune or CI |
| [de.provectus.securecontacts.config.recipe.yaml](de.provectus.securecontacts.config.recipe.yaml) | Stages the production, demo, and manifest configuration files |

## AutoPkg recipes

The recipes are optional deployment helpers. They require:

- macOS with AutoPkg 2.3 or later
- Network access to GitHub and the GitHub API
- Apple silicon target devices; the package recipe currently selects the published ARM64 `.pkg`
- An existing output directory when `OUTPUT_PATH` is overridden

Run the recipes from a clone of this repository by passing their paths directly, or add the repository to AutoPkg's recipe search path and use their identifiers.

### Download and signature verification

```bash
autopkg run ./MacOS/de.provectus.securecontacts.download.recipe.yaml
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
autopkg run ./MacOS/de.provectus.securecontacts.intune.recipe.yaml
```

The default output directory is:

```text
~/Library/AutoPkg/Cache/de.provectus.securecontacts.intune/
```

CI or a custom local directory:

```bash
mkdir -p ./artifacts
autopkg run ./MacOS/de.provectus.securecontacts.intune.recipe.yaml \
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

The signature check enforces publisher identity and package integrity. The SHA256 comparison detects transfer or storage corruption. The `spctl` command separately checks the current Gatekeeper/notarization assessment.

### Stage configuration files

```bash
autopkg run ./MacOS/de.provectus.securecontacts.config.recipe.yaml
```

The default output directory is:

```text
~/Library/AutoPkg/Cache/de.provectus.securecontacts.config/
```

Use `SecureContacts-config-production.plist` as the editable Intune preference-file fragment. Never deploy `SecureContacts-config-demo.plist`; it contains example values only. Follow [SCA-Intune-Config-Manual-Mac.md](SCA-Intune-Config-Manual-Mac.md) for the supported keys and Intune workflow.

For custom output:

```bash
mkdir -p ./artifacts/config
autopkg run ./MacOS/de.provectus.securecontacts.config.recipe.yaml \
	-k OUTPUT_PATH=./artifacts/config
```

## Enterprise rollout guidance

Treat recipe output as a deployment candidate, not as automatic production approval. Pin or retain the approved package in your artifact repository, record its version and SHA256 value, test installation and managed preferences on a pilot device group, and promote the same verified bytes through deployment rings. A newly published GitHub release should not bypass your normal change-control process.

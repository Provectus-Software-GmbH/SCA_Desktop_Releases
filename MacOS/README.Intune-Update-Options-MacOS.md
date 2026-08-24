# Secure Contacts - macOS Intune Update Options

This guide describes three supported macOS update paths for Microsoft Intune:

1. **Organization-owned Graph publishing automation:** an organization-owned macOS runner polls the official GitHub Releases feed, validates the package, and publishes an approved package through Microsoft Graph. This is the enterprise-recommended option for centralized release control, audit evidence, approval gates, and controlled pilot-to-production publishing. It can be implemented with GitHub Actions, Azure DevOps Pipelines, or another approved orchestrator.
2. **Automated staging with manual Intune upload:** the sync script runs AutoPkg and validation, then an administrator reviews and uploads the package through the Intune portal.
3. **Manual GitHub download:** an administrator downloads the PKG and matching checksum from GitHub, validates the signed package, and uploads it through the Intune portal.

All three paths are supported alternatives. Graph publishing provides the most centralized automation and auditability; staging and manual download retain portal-based approval and upload and do not require Microsoft Graph permissions. These paths are operated, approved, and secured by the administrator. This repository does not contain tenant identifiers, client secrets, certificates, access tokens, or an organization-specific hosted production pipeline.

## Choose an update path

Choose exactly one path for each device population. Path 1 publishes centrally through Microsoft Graph; Paths 2 and 3 prepare a package for administrator portal upload.

| Path | How it works | Main advantages | Main tradeoffs |
|---|---|---|---|
| **1. Organization-owned Graph publishing automation** | An organization-owned macOS runner or CI job stages and validates the PKG, waits for approval, and publishes it to an existing Intune app object through Microsoft Graph. GitHub Actions and Azure DevOps Pipelines are supported implementation examples. | Reduces recurring administrator work; supports scheduled polling, audit evidence, approval gates, pilot promotion, and retained rollback artifacts. | Highest setup and maintenance cost; requires an organization-owned Graph identity, permissions, CI, app IDs, and test tenant. |
| **2. Automated staging with manual Intune upload** | The sync script runs AutoPkg and validation without `--publish`; an administrator reviews the artifacts and uploads the PKG in the Intune portal. | Repeatable acquisition and validation; no Graph permissions or credentials; Intune upload and approval remain under administrator control. | Requires a Mac with AutoPkg; portal upload and approval remain manual. |
| **3. Manual GitHub download and Intune upload** | Administrator downloads the PKG and matching checksum from GitHub, verifies the package on a Mac, and uploads the PKG in the Intune portal. | Simplest setup; no AutoPkg, CI, Graph permissions, credentials, or endpoint script; Intune remains the deployment and reporting system. | Administrator repeats the process for every release; no automatic release discovery or upload; validation and approval are manual. |

### Decision guide

- Choose the **Graph pipeline** when you need centralized automation, auditability, approval gates, and controlled pilot-to-production publishing.
- Choose **AutoPkg staging** when you want repeatable package acquisition and validation but prefer portal-based approval and upload.
- Choose **manual GitHub download** when releases are infrequent and you want the fewest tools and permissions.
The paths are alternatives, not cumulative requirements. Azure DevOps and GitHub Actions are alternative implementations of Path 1, not additional update paths. You may use manual GitHub download as a fallback for an organization-owned pipeline.

## Rules for every path

Every package-based path must use one approved stable GitHub release and the matching ARM64 PKG and SHA256 file. Validation must confirm the checksum, the exact Developer ID Installer identity, Gatekeeper acceptance, the `de.provectus.SecureContactsDesktop` bundle identifier, the expected version, and an ARM64 application executable. Reject prereleases, arbitrary filenames, missing checksums, ambiguous artifacts, signer changes, version mismatches, and downgrades unless a separately approved rollback procedure applies.

Record the release version, checksum, signer, validation date, and change reference. Test with a pilot group before production rollout and retain the previous approved package for rollback.

For paths 1 through 3, use [Validate-SecureContactsPackage.sh](Scripts/Validate-SecureContactsPackage.sh) as the common validation boundary when artifacts are staged locally. The validator is Graph-free; publishing is handled separately by the portal or the sync script. For CI-specific setup, use the [GitHub Actions guide](README.Intune-GitHub-Actions.md) or [Azure DevOps guide](README.Intune-Azure-DevOps.md).

## Operating model

| Concern | Organization-owned pipeline | Automated staging with manual upload | Manual GitHub path |
|---|---|---|---|
| Release source | Official GitHub Release | Official GitHub Release | Official GitHub Release API or release asset URL |
| Package preparation | Pipeline downloads the approved release assets directly or uses an approved staging recipe | Sync script runs AutoPkg 2.3+ on macOS | Administrator downloads the PKG and checksum |
| Validation | Validation runner fails closed before any Graph write | Sync script runs the validation runner; administrator reviews the manifest | Administrator runs the documented checks |
| Intune interaction | Your Graph application publishes to an existing pilot app object | Administrator uploads the PKG in the portal | Administrator uploads the PKG in the portal |
| Approval | Your approval gate between validation and production promotion | Your existing change control | Your existing change control |
| Credentials | Your organization-owned Entra application or workload identity | None required by this repository | None required by this repository |
| Rollback | You retain the prior approved PKG and can narrow assignments or restore the prior version | Your existing Intune rollback procedure | Your existing Intune rollback procedure |

The pipeline is not an application update service. It prepares a deployment candidate; Intune remains responsible for device targeting, installation, detection, and reporting.

## Manual GitHub download

Use this path when releases are infrequent and you want the fewest tools and permissions.

### Steps

1. On a Mac, open the [repository Releases page](https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases) and select the approved stable release.
2. Download both matching assets:

   ```text
   SecureContacts-<version>-arm64.pkg
   SecureContacts-<version>-arm64.pkg.sha256
   ```

3. Keep the two assets together and run the verification commands in [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md#2-verify-the-package).
4. Record the release version, package SHA256, signer, validation date, and change reference.
5. Upload the exact validated `SecureContacts-<version>-arm64.pkg` to the existing Secure Contacts macOS app (PKG) object in Intune.
6. Assign the package to the pilot group first. Promote it through your normal deployment rings only after pilot validation.

The shared validation rules apply before upload. Intune receives the package through the portal and reports its detected bundle and version after installation. For rollback, stop or narrow the new assignment and restore a previously retained, validated package through the same controlled portal process.

## Automated staging with manual Intune upload

Use this path when you want repeatable package acquisition and validation but prefer portal-based approval and upload. The sync script runs AutoPkg and the validation runner for you; do not add `--publish` to this workflow.

### Steps

1. On a macOS host, clone or download this repository and install AutoPkg 2.3 or later.
2. Run the validation-only sync command into an isolated output directory:

   ```bash
   mkdir -p ./artifacts
    ./MacOS/Scripts/Sync-SecureContactsToIntune.sh \
       --output ./artifacts \
       --manifest-output ./artifacts/validation-manifest.json
   ```

    The command runs the Intune AutoPkg recipe, stages the PKG and matching checksum, runs `Validate-SecureContactsPackage.sh`, and writes a non-secret validation manifest. It does not authenticate to Graph, upload to Intune, modify an Intune app, or require Graph permissions.

3. Review the validation manifest and staged artifacts. If you operate AutoPkg separately, the equivalent advanced workflow is:

   ```bash
    autopkg run ./MacOS/AutoPkg/de.provectus.securecontacts.intune.recipe.yaml \
       -k OUTPUT_PATH=./artifacts
    ./MacOS/Scripts/Validate-SecureContactsPackage.sh \
       --output ./artifacts \
       --skip-recipe
   ```

4. Record the release version, package SHA256, signer, validation date, and change reference.
5. Upload the exact validated `SecureContacts-<version>-arm64.pkg` to the existing Secure Contacts macOS app (PKG) object in Intune, or create a new object when the portal or package metadata requires it.
6. Assign the package to the pilot group first. Promote it through your normal deployment rings only after pilot validation.

The sync command applies the shared checksum, signer, Gatekeeper, architecture, bundle, and version checks before upload. Intune receives the staged package through the portal and reports its detected bundle and version after installation. For rollback, stop or narrow the new assignment and restore a previously retained, validated package through the same controlled portal process.

Follow [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md) for the full portal workflow and [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md) for managed preferences.

## Organization-owned Graph publishing automation

Use this path when you need centralized release discovery, audit evidence, approval gates, and controlled pilot-to-production publishing. The runner must be macOS; Windows administrators may trigger a macOS CI job but cannot run the Bash and Apple package validation directly on Windows.

You may schedule the following stages on an organization-owned macOS runner or macOS CI job. The approval gate must occur after successful package validation and artifact retention, and before any Graph write.

```text
GitHub Releases -> staging -> local validation -> artifact retention -> approval gate
                                                       |
                                                       v
                                       Graph upload to existing pilot app object
                                                       |
                                                       v
                                           pilot health check -> production approval
```

The current implementation provides staging and validation through [Scripts/Sync-SecureContactsToIntune.sh](Scripts/Sync-SecureContactsToIntune.sh). It writes a non-secret validation manifest, supports an authenticated, read-only beta Graph `--what-if` decision, and can publish an approved package to an explicit existing macOS PKG app. Graph write operations remain behind the explicit `--publish` gate.

For GitHub Actions, use the [GitHub Actions guide](README.Intune-GitHub-Actions.md) and workflow [gh-publish-sca-intune-macos.yml](../.github/workflows/gh-publish-sca-intune-macos.yml). The workflow separates validation from publishing: the protected `intune-production` environment is attached only to the publish job, which depends on successful validation.

For Azure DevOps Pipelines, use the [Azure DevOps guide](README.Intune-Azure-DevOps.md) and example [azure-publish-sca-intune-macos.yml](.azure-pipelines/azure-publish-sca-intune-macos.yml). It runs the same validation and Graph publishing scripts on `macOS-latest`, with Azure DevOps parameters for validation, read-only `whatIf`, and gated `publish`. Configure the protected variables described in the guide and protect the `intune-production` environment. This Azure DevOps definition is an alternative implementation of the Graph publishing path, not an additional update path.

### Preview, publish, and cleanup commands

For production Graph operations, use an organization-owned certificate through Azure CLI:

```bash
export INTUNE_TENANT_ID='<your Entra tenant ID>'
export INTUNE_CLIENT_ID='<your publishing app ID>'
export INTUNE_CERTIFICATE_PATH='/secure/path/publishing-certificate.pem'
export INTUNE_APP_ID='<existing macOS PKG app GUID>'
./MacOS/Scripts/Sync-SecureContactsToIntune.sh --skip-recipe --publish
```

Run the read-only decision before publishing:

```bash
./MacOS/Scripts/Sync-SecureContactsToIntune.sh \
   --output ./artifacts \
   --skip-recipe \
   --what-if
```

The publisher polls each Graph processing phase up to 10 times, with a five-second delay between attempts. Set `INTUNE_POLL_ATTEMPTS` to a higher positive integer when a tenant needs more processing time. To preview abandoned, uncommitted content versions left by failed or test uploads, use:

```bash
./MacOS/Scripts/Sync-SecureContactsToIntune.sh \
   --output ./artifacts \
   --cleanup
```

Cleanup requires `INTUNE_APP_ID` and the same Graph authentication settings as publishing. It does not stage or upload a package and preserves the app's committed content version. It is non-destructive by default; rerun with `--cleanup --apply` only after reviewing and approving the listed candidates. Do not run cleanup concurrently with another publisher.

Protect the certificate and ensure it contains the private key required by Azure CLI. The script uses a temporary private Azure CLI configuration directory, obtains a Microsoft Graph token internally, refreshes it for Graph requests, and removes the temporary state on exit. Do not store the certificate, private key, password file, or token in this repository or in build artifacts.

#### Password-protected certificate files

For a password-protected PFX/P12 or encrypted PEM, keep the password in a protected file and set:

```bash
export INTUNE_CERTIFICATE_PATH='/secure/path/publishing-certificate.p12'
export INTUNE_CERTIFICATE_PASSWORD_FILE='/secure/path/publishing-certificate.password'
```

The publisher temporarily converts the certificate to a mode-600 PEM for Azure CLI and removes it on exit. Never pass the password as an `az login` argument, commit the password file, or retain it as a CI artifact. An unencrypted PEM may be used without `INTUNE_CERTIFICATE_PASSWORD_FILE`, but its filesystem permissions and storage must remain protected.

### Required pipeline stages

1. **Discover:** query the official repository's latest stable release or run on an administrator-approved release/manual schedule. Do not treat an arbitrary tag, prerelease, or filename as approved input.
2. **Stage:** acquire the approved PKG and matching checksum into an isolated `OUTPUT_PATH`. The automated staging path normally runs `de.provectus.securecontacts.intune`; the current GitHub Actions and Azure DevOps examples download the release assets directly and use `--skip-recipe`.
3. **Validate:** run `Validate-SecureContactsPackage.sh`. It checks that there is exactly one expected ARM64 package and checksum, verifies the checksum, confirms the Developer ID signer, runs Gatekeeper assessment, checks the package version, bundle ID, and ARM64 application executable, and rejects malformed or ambiguous artifacts.
4. **Compare:** compare the candidate version with the version currently approved for the Intune app. Do not publish downgrades automatically. Use an explicit override only in a separately approved rollback procedure.
5. **Retain:** store the exact PKG, checksum, validation summary, recipe log, and release URL in your approved artifact store. Do not rebuild or modify the package between validation and upload.
6. **Approve:** require an administrator-controlled approval only after validation succeeds and the exact artifacts are retained. The approval must occur before pilot Graph publishing; a second approval should promote the same bytes to production assignments.
7. **Publish:** upload to an existing Intune macOS app (PKG) object through Microsoft Graph with `--publish` after the package has passed validation and administrator approval.
8. **Observe:** check pilot device install status, detection, application launch, and managed preferences. Expand assignments only when the pilot health criteria pass.

### Required Intune app

The current publisher updates an existing app; it does not create the Intune app object. Before the first publish, create an Intune **macOS app (PKG)** and leave it unassigned while testing. The app must represent Secure Contacts and use the package's production identity:

- Platform: **macOS**
- App type: **macOS app (PKG)**
- Bundle ID: `de.provectus.SecureContactsDesktop`
- Architecture: **Apple silicon / ARM64** package
- Minimum macOS version: choose your supported version, with macOS 15 or later matching the validated test app
- App ID: copy the generated Intune app object ID into `INTUNE_APP_ID`

Do not use a macOS shell script app, LOB app of another type, or a Windows Win32 app ID. The publisher verifies the target resource type before it uploads.

### Initial safety boundaries

Your initial implementation should:

- Publish only to an existing, explicitly configured Secure Contacts app object.
- Target a pilot assignment or pilot app object before production.
- Reject prereleases, ambiguous artifacts, missing checksums, signature changes, and downgrades.
- Keep `--publish` or its equivalent outside the validation runner and disabled by default.
- Require an explicit release/version approval and record the Graph object IDs used.
- Never create app objects, expand production assignments, remove the application, or delete old artifacts automatically.
- Preserve the last known-good package for rollback.

## Organization-owned Entra and Graph setup

Your organization must create an **Entra ID app registration** for the publishing job. Your organization owns the app registration, tenant consent, permissions, secret or certificate, rotation schedule, and audit trail. Do not put any of these values in this repository, a recipe, a shell script, a GitHub issue, or a committed CI variable file.

Configure the app registration as follows:

1. Create an app registration in your Entra tenant.
2. Add Microsoft Graph **Application permissions**: `DeviceManagementApps.ReadWrite.All`.
3. Grant tenant administrator consent for that permission.
4. Configure an organization-managed certificate for production and install Azure CLI on the publishing runner.
5. Set `INTUNE_TENANT_ID`, `INTUNE_CLIENT_ID`, and `INTUNE_CERTIFICATE_PATH` in the protected job environment.
6. Set `INTUNE_APP_ID` to the existing macOS app (PKG) object ID.

The script does not create the Entra registration, grant consent, issue tokens, or manage secret/certificate rotation. The access token must have the Microsoft Graph audience and your tenant's authority; an unrelated user token or token for another resource will fail authentication.

### Preferred authentication

Use workload identity federation or another OIDC-based, short-lived credential when your CI platform supports it. Bind the federated identity to the exact repository, branch or environment, and workflow subject required by your organization. Limit the publishing job to protected environments.

When OIDC is unavailable, use the organization-managed certificate flow shown above. Rotate the certificate according to your policy and remove it immediately if exposure is suspected.

For short-lived local testing only, set `INTUNE_AUTH_METHOD=token` and provide `GRAPH_ACCESS_TOKEN` out-of-band. This fallback is not recommended for CI/CD because the token must be acquired and protected by the caller.

#### Local token-flow test with Azure CLI

For an initial local test on a Mac, Azure CLI can obtain a short-lived Microsoft Graph token through an interactive user login. This is useful for testing `--what-if` against a test Intune app, but it is not suitable for unattended automation or production publishing. The signed-in user must have permission to read the target Intune app, and the token should not be copied into a file, shell history, issue, log, or artifact.

```bash
az login

export INTUNE_TENANT_ID='<your Entra tenant ID>'
export INTUNE_APP_ID='<existing test macOS PKG app GUID>'
export INTUNE_AUTH_METHOD=token
export GRAPH_ACCESS_TOKEN="$(az account get-access-token \
   --resource-type ms-graph \
   --query accessToken \
   --output tsv)"

./MacOS/Scripts/Sync-SecureContactsToIntune.sh \
   --output ./artifacts \
   --skip-recipe \
   --publish \
   --what-if

unset GRAPH_ACCESS_TOKEN INTUNE_TENANT_ID INTUNE_APP_ID INTUNE_AUTH_METHOD
az logout
```

The token-flow test still requires a validated package because `--what-if` runs validation before the read-only Graph lookup. Use `--publish` together with `--what-if` because the script treats `--what-if` as a Graph operation but performs no write. The signed-in user needs suitable delegated Intune application permissions, and the tenant may require administrator consent. These delegated permissions are separate from the production application's `DeviceManagementApps.ReadWrite.All` application permission; a user token is not an equivalent replacement for the production identity. Never use `--publish` without an approved package and your normal change-control process. For production or CI, use the organization-managed certificate or OIDC flow described above.

Use placeholders such as these in pipeline configuration, never real values:

```text
TENANT_ID=<your Entra tenant ID>
CLIENT_ID=<your publishing application ID>
INTUNE_APP_ID=<existing Intune macOS app object ID>
PILOT_GROUP_ID=<your pilot group ID>
```

The publishing identity should receive only the least-privileged Intune application permissions that your approved Graph upload flow requires. A tenant administrator must review and grant consent. Prefer application permissions scoped to the publishing workload; do not reuse a human administrator token.

### Secret storage examples

The following are patterns, not ready-to-run credential instructions:

- GitHub Actions: an environment-protected certificate file or OIDC with an environment approval rule.
- Azure DevOps: a secure file or variable group backed by Azure Key Vault, or workload identity federation.
- Self-hosted macOS runner: Keychain or your approved secret manager, with the runner account restricted to the publishing job.
- Local testing: a test certificate issued for your tenant or the explicit `GRAPH_ACCESS_TOKEN` fallback; never place credentials in a file tracked by Git.

Keep Graph access disabled for validation jobs. Separate validation and publishing identities when practical, and log only tenant/app/object IDs that are safe for your audit system. Never log access tokens, secrets, certificate private keys, or full authorization headers.

## Graph publishing design

The Graph upload publisher uses the Microsoft Graph `/beta` macOS PKG upload API and observed test-tenant behavior. It is an administrator-operated, existing-app publisher rather than a hosted production service. It:

- authenticate with your organization-owned identity;
- query and verify the target app object before upload;
- confirm the app is a macOS PKG app and that its bundle detection metadata is expected;
- upload the exact validated package bytes using the current Microsoft Graph Intune macOS app upload API;
- poll the upload/content processing state and fail on timeout or processing errors;
- verify the resulting app version and included-app metadata;
- leave assignments unchanged until pilot approval;
- record request IDs, object IDs, candidate version, checksum, and final processing state;
- use idempotency or a version/checksum comparison so retries do not create duplicate app objects or publish stale bytes.

Microsoft Graph APIs and Intune upload flows can change. Pin your Graph SDK/API version, test against a non-production app object, and consult the current Microsoft documentation before enabling writes:

- [Microsoft Graph deviceAppManagement overview](https://learn.microsoft.com/graph/api/resources/intune-apps-overview)
- [Microsoft Graph macOS PKG app resource](https://learn.microsoft.com/graph/api/resources/intune-apps-macospkgapp)
- [Microsoft Graph macOS PKG app content resource](https://learn.microsoft.com/graph/api/resources/intune-apps-macospkgappcontent)

## Version, rollback, and failure policy

The candidate version is taken from the release package filename and checked against the application metadata inside the package. A pipeline must fail closed when versions cannot be parsed, the bundle ID is not `de.provectus.SecureContactsDesktop`, the package is not ARM64, the checksum does not match, the signer is unexpected, or more than one candidate exists.

Do not automatically downgrade. For rollback, stop or narrow the new assignment, select a previously retained and validated package, test installation over the newer version on a non-production Mac, and obtain your rollback approval. Intune's macOS app (PKG) type has no general Uninstall assignment intent.

Suggested failure handling:

| Failure | Action |
|---|---|
| No new release | Exit successfully with no publish action and retain the last audit result |
| Missing or ambiguous artifacts | Fail the job and require operator investigation |
| Checksum, signature, Gatekeeper, architecture, or metadata failure | Fail closed; do not call Graph |
| Candidate is equal to approved version | Exit successfully; do not re-upload |
| Candidate is older than approved version | Fail closed unless an approved rollback mode exists |
| Graph upload or processing timeout | Keep assignments unchanged and preserve logs/artifacts |
| Pilot health failure | Stop promotion and keep the prior production assignment |

## Audit and pilot checklist

For each candidate, retain:

- release URL and release version;
- exact PKG filename and SHA256 value;
- AutoPkg version and recipe identifier when a recipe was used;
- validation command output and runner identity;
- Graph tenant, app object, content version, and request IDs, without credentials;
- approval identity and timestamps;
- pilot device results and production promotion decision.

Before enabling a production publisher, test at least one stable release in a test tenant or isolated Intune app object, an equal-version retry, a malformed artifact, a checksum failure, an unexpected signer, a processing timeout, and a pilot failure. Confirm that every negative case leaves Graph assignments unchanged.

## Related documentation

- [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md)
- [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md)
- [MacOS README](README.md)
- [Package validator](Scripts/Validate-SecureContactsPackage.sh)

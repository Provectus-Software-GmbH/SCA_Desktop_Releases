# Secure Contacts - Customer-Owned macOS Update Pipeline

This guide describes two supported macOS update paths for Microsoft Intune:

1. **Manual path:** an administrator runs AutoPkg, validates the signed package, and uploads it to Intune.
2. **Optional customer-owned pipeline:** the customer's macOS runner polls the official GitHub Releases feed, runs the same validation, and can publish an approved package through Microsoft Graph.

The manual path is the default and does not require Graph permissions. The optional pipeline is operated, approved, and secured by the customer. This repository does not contain tenant identifiers, client secrets, certificates, access tokens, or a production publishing workflow.

## Operating model

| Concern | Manual path | Customer-owned pipeline |
|---|---|---|
| Release source | Official GitHub Release | Official GitHub Release API or release asset URL |
| Package preparation | AutoPkg 2.3+ on macOS | AutoPkg 2.3+ on a customer macOS runner or macOS CI job |
| Validation | Administrator runs the documented checks | Validation runner fails closed before any Graph write |
| Intune publishing | Administrator uploads the PKG in the portal | Customer's Graph application publishes to an existing pilot app object |
| Approval | Existing customer change control | Customer approval gate between validation and production promotion |
| Credentials | None required by this repository | Customer-owned Entra application or workload identity |
| Rollback | Existing Intune rollback procedure | Customer retains the prior approved PKG and can narrow assignments or restore the prior version |

The pipeline is not an application update service. It prepares a deployment candidate; Intune remains responsible for device targeting, installation, detection, and reporting.

## Manual workflow

Use this path when a customer wants a human approval and portal upload:

1. On a macOS host, clone or download this repository and install AutoPkg 2.3 or later.
2. Run the Intune recipe into an isolated output directory:

   ```bash
   mkdir -p ./artifacts
   autopkg run ./MacOS/de.provectus.securecontacts.intune.recipe.yaml \\
     -k OUTPUT_PATH=./artifacts
   ```

3. Run the validation-only runner:

   ```bash
   chmod +x ./MacOS/Invoke-SecureContactsAutoUpdate.sh
   ./MacOS/Invoke-SecureContactsAutoUpdate.sh --output ./artifacts
   ```

4. Record the release version, package SHA256, signer, validation date, and change reference.
5. Upload the exact validated `SecureContacts-<version>-arm64.pkg` to the existing Secure Contacts macOS app (PKG) object in Intune, or create a new object when the portal or package metadata requires it.
6. Assign the package to the pilot group first. Promote it through the customer's normal deployment rings only after pilot validation.

Follow [SCA-Intune-Deploy-Manual-MacOS.md](SCA-Intune-Deploy-Manual-MacOS.md) for the full portal workflow and [SCA-Intune-Config-Manual-Mac.md](SCA-Intune-Config-Manual-Mac.md) for managed preferences.

## Optional automated workflow

A customer may schedule the following stages on a macOS runner or macOS CI job:

```text
GitHub Releases -> AutoPkg -> local validation -> artifact retention -> approval gate
                                                       |
                                                       v
                                       Graph upload to existing pilot app object
                                                       |
                                                       v
                                           pilot health check -> production approval
```

The first implementation in this repository is validation-only. A customer publishing job may be added around it, but it must keep Graph write operations outside the validation script and behind an explicit approval gate.

### Required pipeline stages

1. **Discover:** query the official repository's latest stable release or run on a customer-approved release/manual schedule. Do not treat an arbitrary tag, prerelease, or filename as approved input.
2. **Stage:** run `de.provectus.securecontacts.intune` with an isolated `OUTPUT_PATH`.
3. **Validate:** run `Invoke-SecureContactsAutoUpdate.sh`. It checks that there is exactly one expected ARM64 package and checksum, verifies the checksum, confirms the Developer ID signer, runs Gatekeeper assessment, checks the package version, bundle ID, and ARM64 application executable, and rejects malformed or ambiguous artifacts.
4. **Compare:** compare the candidate version with the version currently approved for the Intune app. Do not publish downgrades automatically. Use an explicit override only in a separately approved rollback procedure.
5. **Retain:** store the exact PKG, checksum, validation summary, recipe log, and release URL in the customer's artifact store. Do not rebuild or modify the package between validation and upload.
6. **Approve:** require a customer-controlled approval for pilot publishing. A second approval should promote the same bytes to production assignments.
7. **Publish:** upload to an existing Intune macOS app (PKG) object through the Microsoft Graph deviceAppManagement API. Prefer the supported Intune app upload flow and verify the Graph response and processing state before changing assignments.
8. **Observe:** check pilot device install status, detection, application launch, and managed preferences. Expand assignments only when the pilot health criteria pass.

### Initial safety boundaries

The initial customer implementation should:

- Publish only to an existing, explicitly configured Secure Contacts app object.
- Target a pilot assignment or pilot app object before production.
- Reject prereleases, ambiguous artifacts, missing checksums, signature changes, and downgrades.
- Keep `--publish` or its equivalent outside the validation runner and disabled by default.
- Require an explicit release/version approval and record the Graph object IDs used.
- Never create app objects, expand production assignments, remove the application, or delete old artifacts automatically.
- Preserve the last known-good package for rollback.

## Customer-owned Entra and Graph setup

The customer owns the Entra application, consent, permissions, secret or certificate, rotation schedule, and audit trail. Do not put any of these values in this repository, a recipe, a shell script, a GitHub issue, or a committed CI variable file.

### Preferred authentication

Use workload identity federation or another OIDC-based, short-lived credential when the customer's CI platform supports it. Bind the federated identity to the exact repository, branch or environment, and workflow subject required by the customer. Limit the publishing job to protected environments.

When OIDC is unavailable, use a customer-managed certificate or a short-lived client secret stored in the customer's secret manager. Rotate it according to customer policy and remove it immediately if exposure is suspected.

Use placeholders such as these in pipeline configuration, never real values:

```text
TENANT_ID=<customer Entra tenant ID>
CLIENT_ID=<customer publishing application ID>
INTUNE_APP_ID=<existing Intune macOS app object ID>
PILOT_GROUP_ID=<customer pilot group ID>
```

The publishing identity should receive only the least-privileged Intune application permissions that the customer's approved Graph upload flow requires. A tenant administrator must review and grant consent. Prefer application permissions scoped to the publishing workload; do not reuse a human administrator token.

### Secret storage examples

The following are patterns, not ready-to-run credential instructions:

- GitHub Actions: environment-protected secrets or OIDC with an environment approval rule.
- Azure DevOps: variable groups backed by Azure Key Vault, or workload identity federation.
- Self-hosted macOS runner: Keychain or the customer's approved secret manager, with the runner account restricted to the publishing job.
- Local testing: interactive `az login` or a customer test identity; never place a token in a file tracked by Git.

Keep Graph access disabled for validation jobs. Separate validation and publishing identities when practical, and log only tenant/app/object IDs that are safe for the customer's audit system. Never log access tokens, secrets, certificate private keys, or full authorization headers.

## Graph publishing design

The Graph publisher is intentionally not implemented in the vendor repository because the upload protocol, permissions, app object, assignment model, and approval controls belong to the customer tenant. The customer implementation should:

- authenticate with the customer-owned identity;
- query and verify the target app object before upload;
- confirm the app is a macOS PKG app and that its bundle detection metadata is expected;
- upload the exact validated package bytes using the current Microsoft Graph Intune macOS app upload API;
- poll the upload/content processing state and fail on timeout or processing errors;
- verify the resulting app version and included-app metadata;
- leave assignments unchanged until pilot approval;
- record request IDs, object IDs, candidate version, checksum, and final processing state;
- use idempotency or a version/checksum comparison so retries do not create duplicate app objects or publish stale bytes.

Microsoft Graph APIs and Intune upload flows can change. Pin the customer's Graph SDK/API version, test against a non-production app object, and consult the current Microsoft documentation before enabling writes:

- [Microsoft Graph deviceAppManagement overview](https://learn.microsoft.com/graph/api/resources/intune-apps-overview)
- [Microsoft Graph macOS PKG app resource](https://learn.microsoft.com/graph/api/resources/intune-apps-macospkgapp)
- [Microsoft Graph macOS PKG app content resource](https://learn.microsoft.com/graph/api/resources/intune-apps-macospkgappcontent)

## Version, rollback, and failure policy

The candidate version is taken from the release package filename and checked against the application metadata inside the package. A pipeline must fail closed when versions cannot be parsed, the bundle ID is not `de.provectus.SecureContactsDesktop`, the package is not ARM64, the checksum does not match, the signer is unexpected, or more than one candidate exists.

Do not automatically downgrade. For rollback, stop or narrow the new assignment, select a previously retained and validated package, test installation over the newer version on a non-production Mac, and obtain the customer's rollback approval. Intune's macOS app (PKG) type has no general Uninstall assignment intent.

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
- AutoPkg version and recipe identifier;
- validation command output and runner identity;
- Graph tenant, app object, content version, and request IDs, without credentials;
- approval identity and timestamps;
- pilot device results and production promotion decision.

Before enabling a production publisher, test at least one stable release in a customer test tenant or isolated Intune app object, an equal-version retry, a malformed artifact, a checksum failure, an unexpected signer, a processing timeout, and a pilot failure. Confirm that every negative case leaves Graph assignments unchanged.

## Related documentation

- [SCA-Intune-Deploy-Manual-MacOS.md](SCA-Intune-Deploy-Manual-MacOS.md)
- [SCA-Intune-Config-Manual-Mac.md](SCA-Intune-Config-Manual-Mac.md)
- [MacOS README](README.md)
- [Validation runner](Invoke-SecureContactsAutoUpdate.sh)

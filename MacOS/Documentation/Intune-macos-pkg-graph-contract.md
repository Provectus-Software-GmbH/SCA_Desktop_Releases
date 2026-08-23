# Intune macOS PKG Graph Contract

## Status

This document records the sanitized contract evidence collected from the test tenant on 2026-08-23. The read-only lookup is implemented against Microsoft Graph `/beta`. The upload, commit, and processing sequence is still unverified and is deliberately not implemented.

## Observed app object

Endpoint:

```text
GET https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{app-id}
```

Observed values:

| Property | Value |
|---|---|
| `@odata.type` | `#microsoft.graph.macOSPkgApp` |
| `id` | `1d095fc1-b343-4a64-b2a5-693aa2d3921e` |
| `publishingState` | `published` |
| `uploadState` | `1` |
| `committedContentVersion` | `1` |
| `fileName` | `SecureContacts-0.8.17-arm64.pkg` |
| `size` | `124747504` |
| `isAssigned` | `false` |
| `ignoreVersionDetection` | `true` |
| `minimumSupportedOperatingSystem.v15_0` | `true` |

The test app is unassigned and must remain a disposable test target. The app ID above is evidence only; publishing code must require an explicitly supplied app ID rather than embedding this value.

## Detection metadata

The Secure Contacts application is identified in `includedApps`, not by `primaryBundleId`:

```json
{
  "bundleId": "de.provectus.SecureContactsDesktop",
  "bundleVersion": "0.8.17"
}
```

The object also reports `primaryBundleId` as `com.github.Electron.framework` and `primaryBundleVersion` as `39.8.10`. These fields must not be used for Secure Contacts identity or version comparison.

Because `ignoreVersionDetection` is `true`, the publisher must enforce version monotonicity itself. The publisher should require exactly one matching `includedApps` entry, reject malformed versions and downgrades, and treat an equal version as a no-op.

## Implemented behavior

`MacOS/Scripts/Sync-SecureContactsToIntune.sh` supports:

- validation-only execution by default;
- an explicit `--app-id` or `INTUNE_APP_ID` for Graph decisioning;
- `GRAPH_ACCESS_TOKEN` supplied out-of-band;
- beta GET lookup only;
- strict `macOSPkgApp` type checking;
- exact `includedApps` Secure Contacts matching;
- dotted numeric version comparison;
- `NoUpdateRequired` and `UpdateExistingApp` decision manifests;
- fail-closed downgrade handling;
- no Graph mutation in `--what-if` mode.

The decision manifest contains only app ID, endpoint, resource type, versions, bundle ID, decision, and timestamp. Access tokens and authorization headers are never written to it.

Example:

```bash
INTUNE_APP_ID='<existing app GUID>' \
GRAPH_ACCESS_TOKEN='<short-lived test token>' \
./MacOS/Scripts/Sync-SecureContactsToIntune.sh \
  --output ./artifacts \
  --skip-recipe \
  --publish \
  --what-if
```

## Not yet confirmed

A manual update of the test app is still required to capture and verify:

- content-version creation endpoint and request body;
- file resource creation endpoint and request body;
- encryption metadata requirements;
- upload URL and exact PKG byte transfer;
- file commit/finalize endpoint and payload;
- processing-state endpoint and all terminal/in-progress values;
- required Graph application permissions;
- post-update `includedApps` and `committedContentVersion` behavior.

No upload or commit request should be inferred from the Windows Win32 app flow. Actual publishing remains disabled until these beta macOS PKG operations are observed in the disposable test tenant and covered by tests.

# Secure Contacts Intune Uninstall (macOS)

This guide describes the standalone Intune script for uninstalling the Developer ID PKG/DMG build of Secure Contacts from managed macOS devices.

## Scope

Supported application:

- Path: `/Applications/SecureContacts.app`
- Bundle ID: `de.provectus.SecureContactsDesktop`
- Executable: `SecureContacts`
- Distribution: Developer ID PKG or an application copied from the DMG into `/Applications`

Not supported:

- Mac App Store and MAS development builds
- Copies under a user's `~/Applications` directory
- Arbitrary application paths supplied at runtime

The script does not require changes to the Electron application. It runs independently as root through Intune.

## macOS Support Baseline

The managed deployment baseline is **macOS 15 Sequoia or newer**. The currently deployed major release is **macOS 26 Tahoe**, and macOS 15 is retained as the previous supported release. The script rejects non-macOS systems and macOS versions older than 15 before making any change.

The script remains compatible with the system Bash shipped by macOS, but compatibility with older macOS releases is not part of the supported Secure Contacts deployment policy.

## Files

- Deployment script: `Uninstall-SecureContacts.sh`
- Managed configuration that must remain untouched: `/Library/Managed Preferences/de.provectus.SecureContactsDesktop.plist`
- Intune-captured operation output: standard output

## Required Production Identity

The checked-in script is intentionally blocked from destructive deployment until these constants are populated:

```bash
INTUNE_MODE="REPLACE_WITH_APPLICATION_ONLY_OR_COMPLETE_PURGE"
EXPECTED_TEAM_ID="REPLACE_WITH_PRODUCTION_TEAM_ID"
EXPECTED_DESIGNATED_REQUIREMENT="REPLACE_WITH_PRODUCTION_DESIGNATED_REQUIREMENT"
```

Set `INTUNE_MODE` to `application-only` or `complete-purge` in the reviewed artifact uploaded to Intune. Intune does not pass runtime arguments to uploaded shell scripts. Explicit command-line modes remain available for local testing and override the fixed deployment mode.

Extract the values from a signed production application before uploading the script to Intune:

```bash
codesign -dv --verbose=4 /Applications/SecureContacts.app 2>&1 | grep '^TeamIdentifier='
codesign -d -r- /Applications/SecureContacts.app 2>&1
codesign --verify --deep --strict --verbose=2 /Applications/SecureContacts.app
```

Copy only reviewed values from a notarized production artifact. Do not use the MAS identity from the build configuration for a Developer ID build.

## Modes

### Application Only

```bash
sudo ./Uninstall-SecureContacts.sh application-only
```

This mode:

- Validates the fixed application path and production signing identity.
- Force-stops only processes verified as executing from inside that bundle.
- Removes `/Applications/SecureContacts.app`.
- Preserves every user's Secure Contacts Data and logs.
- Preserves login-item registrations, managed preferences, Keychain state, and package receipts.

Removing the application while preserving its login item can leave a stale macOS registration. The script reports that residual explicitly.

### Complete Purge

```bash
sudo ./Uninstall-SecureContacts.sh complete-purge
```

This mode additionally enumerates eligible local users through directory services and removes these exact paths from each validated home:

```text
~/Library/Application Support/SecureContacts/Data
~/Library/Logs/SecureContacts
```

Deleting `Data` removes the application-owned settings, Level stores, SCACore cache, MSAL cache files, runtime authentication state, avatars, call history, and `secure-settings.bin` stored below that directory. It does not remove unrelated state outside `Data`.

## Dry Run

Use dry-run before destructive deployment:

```bash
./Uninstall-SecureContacts.sh complete-purge --dry-run
```

Dry-run performs validation and reports planned operations without sending signals, changing login items, or deleting files. Production identity constants are still required so dry-run cannot give approval to an unconfigured script.

## Safety Behavior

Before making a change, the script:

1. Requires macOS and, for destructive modes, root privileges.
2. Rejects a symlink or unexpected application path.
3. Validates the bundle identifier, executable, package type, owner, permissions, code signature, Team ID, and designated requirement.
4. In complete-purge mode, enumerates eligible users from directory-service records and accepts only canonical local homes directly below `/Users`.
5. In complete-purge mode, requires each home to be owned by its directory-service UID and rejects duplicate homes, symlinked path components, and filesystem crossings.
6. Captures managed-preference metadata for post-operation comparison.

Process termination is PID- and path-specific. The script does not use basename-only `killall`, broad `pkill`, or an unverified process-name match. It revalidates each candidate's executable path before sending `SIGKILL` and verifies no bundle-owned process remains before deletion.

Missing bundle or data paths are idempotent `already_absent` results.

This remains a shell-only implementation. A PID can theoretically be reused between the final executable-path check and `SIGKILL`, and a validated user-writable ancestor can theoretically be replaced before `find` opens it. The script minimizes these windows through immediate revalidation, rejects links and filesystem crossings, and fails when constrained deletion cannot remove the validated root. Eliminating these races entirely would require a native helper using process handles and descriptor-relative filesystem operations.

## Login-Item Limitation

During complete purge, the script attempts narrowly scoped legacy login-item removal for the active console user. It matches the exact application path and does not reset unrelated login items.

A root shell cannot reliably unregister Electron's modern per-user `SMAppService` registration for inactive users. Consequently:

- Login-item cleanup is best effort.
- Modern or inactive-user registrations may remain after purge.
- This condition is emitted as a structured warning and does not make filesystem cleanup fail.
- The script never runs `sfltool resetbtm`, `sfltool resetlist`, or deletes shared login-item databases.

Guaranteed modern login-item removal would require a future app-owned command or signed helper operating in each user's context.

## Explicit Exclusions

The script never modifies or removes:

- `/Library/Managed Preferences/de.provectus.SecureContactsDesktop.plist`
- Arbitrary macOS Keychain items
- Intune configuration profiles
- PKG receipts
- Unrelated login items
- Files outside the fixed application, Data, and log paths

File deletion removes application-owned encrypted files, but it does not claim to remove all Electron/macOS Keychain metadata.

## Intune Deployment

1. Populate and review the production signing identity constants.
2. Set `INTUNE_MODE` to the selected mode and review the resulting fixed deployment artifact.
3. Upload `Uninstall-SecureContacts.sh` under Devices -> macOS -> Shell scripts.
4. Configure the script to run as the signed-in user: **No**.
5. Assign the script to the intended device group.
6. Test an explicitly invoked `--dry-run` artifact on controlled devices before assigning the fixed destructive version. Do not source mode values from user-writable files.

Intune considers exit code `0` successful and retries nonzero failures according to assignment policy.

## Exit Codes

| Code | Meaning |
|---:|---|
| `0` | Operation completed; warnings may still describe login-item residuals |
| `64` | Invalid arguments |
| `77` | Destructive execution was not root |
| `78` | Production signing identity is not configured |
| `80` | Unsafe path, identity mismatch, or another preflight failure |
| `81` | Process identity changed, termination failed, or a process survived |
| `82` | Filesystem deletion failed |
| `83` | A deletion or managed-preference postcondition failed |

Operational stdout lines are JSON objects containing a timestamp, run ID, mode, dry-run state, action, result, reason, target, and user. Invalid invocation prints plaintext usage and exits with `64`. Warnings such as `modern_registration_may_remain` require operator review even when the exit code is `0`. The script intentionally creates no root-owned log file; Intune captures standard output.

## Detection and Verification

Application-only detection should require the application bundle to be absent:

```bash
test ! -e /Applications/SecureContacts.app
```

Complete-purge verification must additionally inspect every eligible local user's exact Data and log paths. Do not use root's `$HOME` as the user-data location.

After execution, verify:

- No process executes from `/Applications/SecureContacts.app/Contents/`.
- The application bundle is absent.
- Application-only mode preserved Data and logs.
- Complete-purge mode removed Data and logs for every reachable eligible user.
- Managed-preference hash, owner, mode, and modification time are unchanged.
- Unrelated files and login items remain intact.

## Package Receipts and Reinstall

The first release intentionally retains PKG receipts. DMG copies do not have a package receipt, and the source repository does not establish the final signed PKG receipt identifier authoritatively.

Inspect a production PKG if receipt management is considered later:

```bash
pkgutil --check-signature SecureContacts.pkg
pkgutil --payload-files SecureContacts.pkg
pkgutil --pkgs | grep -i secure
```

Do not add `pkgutil --forget` until the exact receipt and reinstall/upgrade policy are reviewed. Reinstallation after either mode should use the normal signed PKG or DMG deployment.

## Required macOS Acceptance Tests

Before broad rollout, test on supported real macOS versions with:

- App open and closed
- TeamsCallMonitor and Electron helpers active
- Multiple local users, including logged-out users
- Login item enabled and disabled
- Bundle, Data, or logs already absent
- Locked or unavailable user homes; in `complete-purge` mode, verify the script fails safely during preflight rather than partially cleaning the device
- Repeated execution
- Identity mismatch and modified bundle
- Reinstall after application-only and complete purge
- Actual Intune root execution

Test on macOS 15 Sequoia and macOS 26 Tahoe separately because login-item behavior can differ between supported releases. Do not treat macOS 12 or earlier as supported acceptance targets.

## Related files and references

- [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md) - macOS PKG deployment, update, rollback, and removal-workflow context
- [README.Intune-Config-MacOS.md](README.Intune-Config-MacOS.md) - managed-preferences configuration guide
- [README.md](README.md) - macOS deployment files and operational entry points
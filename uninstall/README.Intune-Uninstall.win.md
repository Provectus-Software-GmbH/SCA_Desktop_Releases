# Secure Contacts Windows Uninstall and Optional Data Purge

[`Uninstall-SecureContacts.ps1`](Uninstall-SecureContacts.ps1) is a standalone administrator/SYSTEM script for removing the machine-installed Secure Contacts application through Intune or manual PowerShell execution. The default `ApplicationOnly` mode removes the application while preserving user data; `CompletePurge` is an optional, destructive data-cleanup mode.

## Modes

| Mode | Removes application | Removes Secure Contacts user data | Recommended use |
|---|---:|---:|---|
| `ApplicationOnly` | Yes | No | Standard Intune uninstall and normal application removal |
| `CompletePurge` | Yes | Yes | Device retirement, reprovisioning, or explicitly approved cleanup |

Application-only removal preserves per-user data, logs, and managed policy:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\uninstall\Uninstall-SecureContacts.ps1 -Mode ApplicationOnly
```

> Warning: `CompletePurge` deletes Secure Contacts data for every eligible local Windows profile on the device, including profiles whose users are not currently logged in. Use it only when that data removal is explicitly approved.

Complete purge removes the application and the verified Secure Contacts data directory for each eligible local profile:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\uninstall\Uninstall-SecureContacts.ps1 -Mode CompletePurge
```

Use `-WhatIf` to perform discovery and validation without changing application processes, registry state, or application data:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\uninstall\Uninstall-SecureContacts.ps1 -Mode CompletePurge -WhatIf
```

An optional `-LogPath` writes the JSON-lines event stream to a local file in addition to standard output. Supplying `-LogPath` can create or append to that log file, including during a `-WhatIf` run.

For an Intune Win32 app, include `Uninstall-SecureContacts.ps1` in the `.intunewin` package and run the standard uninstall command in 64-bit SYSTEM context:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\uninstall\Uninstall-SecureContacts.ps1 -Mode ApplicationOnly
```

## Scope

The script discovers an exact `SecureContacts` or legacy `Secure Contacts` uninstall registration in both standard Windows registry views. MSI registrations are removed with `msiexec.exe /x <ProductCode> /qn /norestart`; non-MSI registrations use the registered quiet-uninstall command when it is safely parseable. Some MSI registrations do not expose `InstallLocation`; those are still safely removed by product code, with path-based process and residual-file checks skipped when the location is unavailable.

Before uninstalling, it verifies and stops only `SecureContacts.exe` and `TeamsCallMonitor.exe` processes whose executable paths are beneath the registered installation directory. It does not use an unrestricted process-name kill.

`CompletePurge` removes only this app-owned target for validated local profiles:

```text
%USERPROFILE%\AppData\Local\SecureContacts\Data
```

The script rejects unsafe profile paths, reparse points, and targets outside the profile root. It does not remove arbitrary `%LOCALAPPDATA%` content, Windows Credential Manager entries, or unrelated Electron/Chromium caches.

The managed policy key remains untouched by design. This allows the managed configuration to remain available if Secure Contacts is later reinstalled:

```text
HKLM\SOFTWARE\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop
```

Logs are deliberately not deleted until the physical packaged Windows path returned by Electron `app.getPath('logs')` has been confirmed and added as an explicit validated target.

## Exit Codes

- `0`: completed successfully.
- `77`: administrator or SYSTEM context is required.
- `80`: preflight or identity validation failed.
- `81`: a verified application process could not be stopped.
- `82`: uninstall or data removal failed.
- `83`: post-uninstall verification failed.

MSI exit codes `0`, `1641`, and `3010` are treated as successful uninstall results.

## Intune Notes

Run the script as a 64-bit process in the SYSTEM context for device-wide removal. Test the command with `-WhatIf` first on a representative device. Complete purge enumerates local profiles, including profiles that are not currently logged in, but locked files can still cause the operation to fail. Use `ApplicationOnly` for the normal Win32 app uninstall assignment; deploy `CompletePurge` separately when approved data cleanup is required.

The script is intentionally idempotent: an absent application or absent data target is reported as already absent rather than treated as an error.

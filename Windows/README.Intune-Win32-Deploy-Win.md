# Secure Contacts — Intune Win32 App Deployment Manual (Windows)

This guide covers deploying Secure Contacts as an Intune **Win32 app** with the provided PowerShell scripts. The same deploy script can also be reused in SCCM/MECM-style packaged deployments. By default, the script downloads and installs the latest release from GitHub Releases, and an optional local-content mode installs a bundled MSI from the package itself.

> **Related:** Configure Secure Contacts policies using [README.Intune-Config-Win.md](README.Intune-Config-Win.md).

## How it works

| Script | Role in Intune |
|---|---|
| [`Install-SecureContacts.ps1`](Install-SecureContacts.ps1) | Install command — default GitHub-download mode or optional packaged-local MSI mode, both with silent install behavior |
| [`Uninstall-SecureContacts.ps1`](Uninstall-SecureContacts.ps1) | Uninstall command — application-only removal by default, with an optional complete data purge mode |
| [`Test-SecureContactsInstalled.ps1`](Test-SecureContactsInstalled.ps1) | Detection rule (static) — checks registry for Secure Contacts presence and minimum version compliance |
| [`Test-SecureContactsUpToDate.ps1`](Test-SecureContactsUpToDate.ps1) | Detection rule (dynamic) — compares installed version with the latest eligible GitHub release |

In GitHub-download mode, the install script is version-aware. Whenever Intune executes the installation, the script compares the latest GitHub release with the installed version and exits 0 without downloading if the device is already current.

## Choose your operating mode first

Use one of these mode combinations consistently:

1. **GitHub-download install + dynamic detection**
   - Install: `Install-SecureContacts.ps1` (GitHub mode)
   - Detection: `Test-SecureContactsUpToDate.ps1`
   - Best when you want release tracking without repackaging for every app update.

2. **Packaged-local install + static detection**
   - Install: `Install-SecureContacts.ps1 -MsiPath ...`
   - Detection: `Test-SecureContactsInstalled.ps1`
   - Best when devices should not download installers at runtime.

## Deployment Decision Matrix

| Requirement | Recommended mode |
|---|---|
| Always latest version | GitHub-download install + dynamic detection |
| Fully controlled change management | Packaged-local install + static detection |
| No internet access from endpoints | Packaged-local install + static detection |
| Minimal packaging effort | GitHub-download install + dynamic detection |
| Highly regulated environment | Packaged-local install + static detection |

## Prerequisites

- Microsoft Intune administrator permissions.
- Windows devices managed by Intune (Windows 10 or later, 64-bit).
- [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) (`IntuneWinAppUtil.exe`) — free download, no install required.
- Internet access from managed devices to `api.github.com` and `objects.githubusercontent.com` when using the default GitHub-download mode.

## Supported Platforms

- Windows 10 (64-bit)
- Windows 11 (64-bit)

Secure Contacts supports x64 architectures only.

## Network Requirements

For GitHub-download mode, client devices must be able to reach:

- api.github.com (release metadata)
- objects.githubusercontent.com (installer download)

HTTPS (TCP 443) is required.

If outbound internet access is restricted, use packaged-local MSI mode instead.

## Update Behavior

GitHub-download mode:

- Installation always targets the latest eligible GitHub release.
- Intune detects new versions through `Test-SecureContactsUpToDate.ps1`.
- No new `.intunewin` package is required.

Packaged-local mode:

- Administrators control when new MSI versions are packaged and deployed.
- Update detection relies on the configured `$MinimumVersion` value.

## Logging

Install logs are written to: `%TEMP%\SecureContacts_*_install.log`

When running under Intune `SYSTEM` context, `%TEMP%` maps to: `C:\Windows\Temp`

## Step 1 — Package the script as a Win32 app

The Intune Win32 app format requires a `.intunewin` package.

1. Download `IntuneWinAppUtil.exe` from the [Microsoft Win32 Content Prep Tool releases page](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases).

2. Choose one packaging pattern and stage the files accordingly.

   **GitHub-download mode** packages the install and uninstall scripts. Upload the detection script separately in Intune:

   ```
   C:\staging\SCA-Deploy\
      Install-SecureContacts.ps1
      Uninstall-SecureContacts.ps1
   ```

   **Packaged-local mode** bundles the MSI with the install and uninstall scripts:

   Download the MSI from the repository Releases assets first:
   https://github.com/Provectus-Software-GmbH/SCA_Desktop_Releases/releases
   You can rename it to `SecureContacts.msi` to match the example below, but renaming is optional.
   If you keep a different filename, pass that exact filename in `-MsiPath`.

   ```
   C:\staging\SCA-Deploy\
      Install-SecureContacts.ps1
      Uninstall-SecureContacts.ps1
      SecureContacts.msi
   ```

3. Run the packaging tool:

   ```powershell
   .\IntuneWinAppUtil.exe `
      -c "C:\staging\SCA-Deploy" `
      -s "Install-SecureContacts.ps1" `
      -o "C:\staging\output"
   ```

    This produces `Install-SecureContacts.intunewin` in `C:\staging\output`.

## Step 2 — Create the Win32 app in Intune

1. In [Intune Admin Center](https://intune.microsoft.com), go to **Apps** → **Windows** → **Add**.
2. Select **App type: Windows app (Win32)** and click **Select**.
3. Upload `Install-SecureContacts.intunewin`.
4. Fill in the app information:

   | Field | Value |
   |---|---|
   | Name | Secure Contacts |
   | Publisher | Provectus Software GmbH |
   | Version | Informational only (does not control install/update logic). Suggested: `Script-managed (GitHub latest)` for GitHub-download mode, or the bundled MSI version (for example `0.8.2.0`) for packaged-local mode. |

## Step 3 — Configure install and uninstall commands

### Install command

#### Default GitHub-download mode

```
powershell.exe -ExecutionPolicy Bypass -File Install-SecureContacts.ps1
```

This is the recommended command for Intune. It maps MSI exit code `3010` to script exit code `0` by default. Use `-PassRebootCode` only if you want reboot-required installs reported back to the deployment system.

If your environment needs a GitHub API token (see `Install-SecureContacts.ps1` for when this applies):

```
powershell.exe -ExecutionPolicy Bypass -File Install-SecureContacts.ps1 -GitHubToken "github_pat_xxx"
```

The Intune portal encrypts the install command — the token is not visible to end users.

#### Packaged-local MSI mode

If the `.intunewin` package or SCCM content source already includes the MSI, use:

```
powershell.exe -ExecutionPolicy Bypass -File Install-SecureContacts.ps1 -MsiPath ".\SecureContacts.msi"
```

Relative paths are resolved from the same folder as `Install-SecureContacts.ps1`, so the command does not depend on the caller's working directory.
If your MSI has a different filename, use that exact name in `-MsiPath`.

When you test this command manually outside Intune or SCCM/MECM, run it from an elevated PowerShell session. The MSI installs per-machine and will fail with Windows Installer error `1925` if the shell does not have administrator rights.

If you use the script with SCCM/MECM and want reboot-required installs to remain visible to the deployment system, use:

```
powershell.exe -ExecutionPolicy Bypass -File Install-SecureContacts.ps1 -PassRebootCode
```

To combine packaged-local MSI usage with SCCM/MECM reboot reporting, use:

```
powershell.exe -ExecutionPolicy Bypass -File Install-SecureContacts.ps1 -MsiPath ".\SecureContacts.msi" -PassRebootCode
```

### Uninstall command

Include `Uninstall-SecureContacts.ps1` in the `.intunewin` package and use the following standard uninstall command:

```
powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-SecureContacts.ps1 -Mode ApplicationOnly
```

`ApplicationOnly` removes the registered Secure Contacts application while preserving per-user data, logs, and the managed policy. The script discovers exact Secure Contacts registrations in both standard registry views, supports the validated MSI and supported non-MSI paths, verifies application process paths before stopping them, and verifies that the application is no longer registered afterward.

Set **Install behavior** to **System** and configure the package to run scripts as a **64-bit process**. See [README.Intune-Uninstall.md](README.Intune-Uninstall.md) for the complete safety scope and exit codes.

For device retirement, reprovisioning, or another explicitly approved cleanup scenario, use the separate complete purge workflow:

```
powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-SecureContacts.ps1 -Mode CompletePurge
```

`CompletePurge` removes the verified Secure Contacts data directory for every eligible local profile, including profiles that are not currently logged in. Do not use it as the default Win32 app uninstall command.

## Step 4 — Set requirements

| Setting | Value |
|---|---|
| Operating system architecture | 64-bit |
| Minimum operating system | Windows 10 |

Add any additional requirements (disk space, RAM) as needed for your environment.

## Step 5 — Configure the detection rule

1. Under **Detection rules**, select **Rule format: Use a custom detection script**.
2. Upload the detection script for your chosen mode:
   - `Test-SecureContactsUpToDate.ps1` for **GitHub-download** + dynamic detection
   - `Test-SecureContactsInstalled.ps1` for **packaged-local** + static minimum-version detection
3. Set **Run script as 32-bit process on 64-bit clients**: **No**.
4. Set **Enforce script signature check**: as required by your tenant policy.

Detection behavior differs by script:

- **`Test-SecureContactsUpToDate.ps1` (dynamic):** compares installed version to latest eligible GitHub release and returns non-compliant when an update is available.
- **`Test-SecureContactsInstalled.ps1` (static):** exits 0 with output when the app is detected at or above `$MinimumVersion`. Update `$MinimumVersion` before deploying if you want to enforce a minimum release.

If you enable script signature enforcement, ensure the selected detection script is signed with a certificate trusted by the managed devices.

## Step 6 — Assign the app

- Assign to **device groups** (recommended — the MSI is a per-machine install).
- User-group assignment is supported but requires the user to be signed in for the assignment to evaluate.

## Step 7 — Validate

On a test device, trigger an Intune sync and confirm:

1. Secure Contacts appears in **Settings > Apps > Installed apps** on the device (or in `C:\Program Files\Secure Contacts`).
2. The registry key is present:
   ```
   HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{product-code}
   DisplayName = Secure Contacts
   DisplayVersion = 0.8.x.0
   ```
   > Note: `{ProductCode}` is the MSI ProductCode assigned by Windows Installer and may vary between releases.
3. Run your selected detection script manually:
   - `Test-SecureContactsUpToDate.ps1` for dynamic GitHub-update detection
   - `Test-SecureContactsInstalled.ps1` for static minimum-version detection
4. Check the install log if needed: `%TEMP%\SecureContacts_*_install.log` (kept on failure only). When the script runs from Intune as `SYSTEM`, `%TEMP%` refers to the system temp directory, typically `C:\Windows\Temp`.

For uninstall validation, confirm that:

5. The Secure Contacts uninstall registration is absent.
6. `SecureContacts.exe` and `TeamsCallMonitor.exe` are no longer running from the application installation directory.
7. After `ApplicationOnly`, the expected per-user data remains.
8. After an approved `CompletePurge`, the verified `SecureContacts\\Data` target is absent for eligible profiles.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (installed, updated, or already up to date) |
| 3010 | Success — reboot required to complete installation (returned only when `-PassRebootCode` is used) |
| 1603 | Fatal failure — download error, hash mismatch, or MSI error |
| Other | MSI exit code propagated as-is |

Confirm that the Intune app return code mapping treats `3010` as a soft reboot or success condition in your tenant.

## Notes

- **Deployment modes:** GitHub-download mode minimizes packaging work and automatically targets the latest release. Packaged-local mode removes the runtime GitHub dependency, but each MSI update requires a new `.intunewin` package or SCCM content revision.
- **Auto-update behavior depends on detection script:**
   - With `Test-SecureContactsUpToDate.ps1`, update detection follows latest eligible GitHub release.
   - With `Test-SecureContactsInstalled.ps1`, update detection follows the configured `$MinimumVersion`.
   - In both cases, GitHub-download install mode does not require a new `.intunewin` package for each app release.
- **Internet access:** The install script calls `api.github.com` and downloads from `objects.githubusercontent.com` only in GitHub-download mode. If all devices share a single egress IP, add a GitHub API token to avoid the 60 requests/hour rate limit — see `Install-SecureContacts.ps1` for instructions.
- **Manual test context:** A local manual run of `Install-SecureContacts.ps1` must be elevated for per-machine installation. Intune Win32 installs running as `SYSTEM` and SCCM/MECM installs running with administrative context already satisfy this requirement.
- **Running app instances:** The deployment script stops running Secure Contacts processes before upgrade so MSI updates are less likely to fail because of locked files.
- **Uninstall behavior:** Use `ApplicationOnly` for the normal Intune uninstall assignment. `CompletePurge` is a separate destructive cleanup workflow; see [`README.Intune-Uninstall.md`](README.Intune-Uninstall.md) for exit codes, safety checks, and manual execution.

## Related files

- [`Install-SecureContacts.ps1`](Install-SecureContacts.ps1) — install/update script (see inline documentation for all parameters)
- [`Test-SecureContactsInstalled.ps1`](Test-SecureContactsInstalled.ps1) — static detection script (update `$MinimumVersion` before deploying)
- [`Test-SecureContactsUpToDate.ps1`](Test-SecureContactsUpToDate.ps1) — dynamic GitHub-release detection script
- [`Uninstall-SecureContacts.ps1`](Uninstall-SecureContacts.ps1) — application-only uninstall or optional complete data purge
- [`README.Intune-Uninstall.md`](README.Intune-Uninstall.md) — uninstall modes, safety scope, Intune usage, and exit codes
- [`README.Intune-Config-Win.md`](README.Intune-Config-Win.md) — policy configuration guide (run after app deployment)

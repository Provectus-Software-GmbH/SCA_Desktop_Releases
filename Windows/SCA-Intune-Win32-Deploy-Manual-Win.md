# Secure Contacts — Intune Win32 App Deployment Manual (Windows)

This guide covers deploying Secure Contacts as an Intune **Win32 app** with the provided PowerShell scripts. The same deploy script can also be reused in SCCM/MECM-style packaged deployments. By default, the script downloads and installs the latest release from GitHub Releases, and an optional local-content mode installs a bundled MSI from the package itself.

> **Related:** Configure Secure Contacts policies using [SCA-Intune-Config-Manual-Win.md](SCA-Intune-Config-Manual-Win.md).

## How it works

| Script | Role in Intune |
|---|---|
| [`Deploy-SecureContacts.ps1`](Deploy-SecureContacts.ps1) | Install command — default GitHub-download mode or optional packaged-local MSI mode, both with silent install behavior |
| [`Detect-SecureContacts.ps1`](Detect-SecureContacts.ps1) | Detection rule — checks registry for Secure Contacts presence and version compliance |

In GitHub-download mode, the install script is version-aware. Whenever Intune executes the installation, the script compares the latest GitHub release with the installed version and exits 0 without downloading if the device is already current.

## Prerequisites

- Microsoft Intune administrator permissions.
- Windows devices managed by Intune (Windows 10 or later, 64-bit).
- [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) (`IntuneWinAppUtil.exe`) — free download, no install required.
- Internet access from managed devices to `api.github.com` and `objects.githubusercontent.com` when using the default GitHub-download mode.

## Step 1 — Package the script as a Win32 app

The Intune Win32 app format requires a `.intunewin` package.

1. Download `IntuneWinAppUtil.exe` from the [Microsoft Win32 Content Prep Tool releases page](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases).

2. Choose one packaging pattern and stage the files accordingly.

   GitHub-download mode packages only the scripts:

   ```
   C:\staging\SCA-Deploy\
       Deploy-SecureContacts.ps1
       Detect-SecureContacts.ps1
   ```

   Packaged-local mode bundles the MSI with the scripts:

   ```
   C:\staging\SCA-Deploy\
      Deploy-SecureContacts.ps1
      Detect-SecureContacts.ps1
      SecureContacts.msi
   ```

3. Run the packaging tool:

   ```powershell
   .\IntuneWinAppUtil.exe `
     -c "C:\staging\SCA-Deploy" `
     -s "Deploy-SecureContacts.ps1" `
     -o "C:\staging\output"
   ```

   This produces `Deploy-SecureContacts.intunewin` in `C:\staging\output`.

## Step 2 — Create the Win32 app in Intune

1. In [Intune Admin Center](https://intune.microsoft.com), go to **Apps** → **Windows** → **Add**.
2. Select **App type: Windows app (Win32)** and click **Select**.
3. Upload `Deploy-SecureContacts.intunewin`.
4. Fill in the app information:

   | Field | Value |
   |---|---|
   | Name | Secure Contacts |
   | Publisher | Provectus Software GmbH |
   | Version | _(optional informational value — GitHub mode installs the latest release, local mode installs the bundled MSI)_ |

## Step 3 — Configure install and uninstall commands

### Install command

#### Default GitHub-download mode

```
powershell.exe -ExecutionPolicy Bypass -File Deploy-SecureContacts.ps1
```

This is the recommended command for Intune. It maps MSI exit code `3010` to script exit code `0` by default. Use `-PassRebootCode` only if you want reboot-required installs reported back to the deployment system.

If your environment needs a GitHub API token (see `Deploy-SecureContacts.ps1` for when this applies):

```
powershell.exe -ExecutionPolicy Bypass -File Deploy-SecureContacts.ps1 -GitHubToken "github_pat_xxx"
```

The Intune portal encrypts the install command — the token is not visible to end users.

#### Packaged-local MSI mode

If the `.intunewin` package or SCCM content source already includes the MSI, use:

```
powershell.exe -ExecutionPolicy Bypass -File Deploy-SecureContacts.ps1 -MsiPath ".\SecureContacts.msi"
```

Relative paths are resolved from the same folder as `Deploy-SecureContacts.ps1`, so the command does not depend on the caller's working directory.

When you test this command manually outside Intune or SCCM/MECM, run it from an elevated PowerShell session. The MSI installs per-machine and will fail with Windows Installer error `1925` if the shell does not have administrator rights.

If you use the script with SCCM/MECM and want reboot-required installs to remain visible to the deployment system, use:

```
powershell.exe -ExecutionPolicy Bypass -File Deploy-SecureContacts.ps1 -PassRebootCode
```

To combine packaged-local MSI usage with SCCM/MECM reboot reporting, use:

```
powershell.exe -ExecutionPolicy Bypass -File Deploy-SecureContacts.ps1 -MsiPath ".\SecureContacts.msi" -PassRebootCode
```

### Uninstall command

Use the following dynamic uninstall command. It looks up the installed product code from the registry at uninstall time:

```
powershell.exe -ExecutionPolicy Bypass -Command "& { $app = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Secure Contacts*' } | Select-Object -First 1; if ($app) { Start-Process msiexec.exe -ArgumentList \"/x $($app.PSChildName) /qn /norestart\" -Wait } }"
```

### Install behavior

Set **Install behavior** to **System** (the script requires administrator privileges to install to `C:\Program Files\`).

## Step 4 — Configure the detection rule

1. Under **Detection rules**, select **Rule format: Use a custom detection script**.
2. Upload `Detect-SecureContacts.ps1`.
3. Set **Run script as 32-bit process on 64-bit clients**: **No**.
4. Set **Enforce script signature check**: as required by your tenant policy.

The script exits 0 with output when the app is detected at or above the minimum version defined in the script (`$MinimumVersion`). Update `$MinimumVersion` in the script before deploying if you want to enforce a minimum release.

If you enable script signature enforcement, ensure `Detect-SecureContacts.ps1` is signed with a certificate trusted by the managed devices.

## Step 5 — Set requirements

| Setting | Value |
|---|---|
| Operating system architecture | 64-bit |
| Minimum operating system | Windows 10 |

Add any additional requirements (disk space, RAM) as needed for your environment.

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
3. Run `Detect-SecureContacts.ps1` manually — it should exit 0 with output.
4. Check the install log if needed: `%TEMP%\SecureContacts_*_install.log` (kept on failure only). When the script runs from Intune as `SYSTEM`, `%TEMP%` refers to the system temp directory, typically `C:\Windows\Temp`.

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
- **Auto-update:** In GitHub-download mode, re-running the assignment (or increasing the required version in `Detect-SecureContacts.ps1`) is sufficient to trigger an update — no new `.intunewin` package needed. In packaged-local mode, update the bundled MSI and redistribute the package when you want to roll out a newer app version.
- **Internet access:** The deploy script calls `api.github.com` and downloads from `objects.githubusercontent.com` only in GitHub-download mode. If all devices share a single egress IP, add a GitHub API token to avoid the 60 requests/hour rate limit — see `Deploy-SecureContacts.ps1` for instructions.
- **Manual test context:** A local manual run of `Deploy-SecureContacts.ps1` must be elevated for per-machine installation. Intune Win32 installs running as `SYSTEM` and SCCM/MECM installs running with administrative context already satisfy this requirement.
- **Running app instances:** The deployment script stops running Secure Contacts processes before upgrade so MSI updates are less likely to fail because of locked files.

## Related files

- [`Deploy-SecureContacts.ps1`](Deploy-SecureContacts.ps1) — install/update script (see inline documentation for all parameters)
- [`Detect-SecureContacts.ps1`](Detect-SecureContacts.ps1) — detection script (update `$MinimumVersion` before deploying)
- [`SCA-Intune-Config-Manual-Win.md`](SCA-Intune-Config-Manual-Win.md) — policy configuration guide (run after app deployment)

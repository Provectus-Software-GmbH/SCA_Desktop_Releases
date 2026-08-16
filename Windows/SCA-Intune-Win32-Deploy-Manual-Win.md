# Secure Contacts — Intune Win32 App Deployment Manual (Windows)

This guide covers deploying Secure Contacts as an Intune **Win32 app** using the provided PowerShell scripts. The scripts download and install the latest release directly from GitHub Releases — no manual MSI management required.

> **Related:** Configure Secure Contacts policies using [SCA-Intune-Config-Manual-Win.md](SCA-Intune-Config-Manual-Win.md).

## How it works

| Script | Role in Intune |
|---|---|
| [`Deploy-SecureContacts.ps1`](Deploy-SecureContacts.ps1) | Install command — queries GitHub Releases, downloads and verifies the MSI, installs silently |
| [`Detect-SecureContacts.ps1`](Detect-SecureContacts.ps1) | Detection rule — checks registry for Secure Contacts presence and version compliance |

The install script is self-updating: whenever Intune runs the install command, it compares the latest GitHub release against the installed version and exits 0 without downloading if the device is already up to date.

## Prerequisites

- Microsoft Intune administrator permissions.
- Windows devices managed by Intune (Windows 10 or later, 64-bit).
- [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) (`IntuneWinAppUtil.exe`) — free download, no install required.
- Internet access from managed devices to `api.github.com` and `objects.githubusercontent.com`.

## Step 1 — Package the script as a Win32 app

The Intune Win32 app format requires a `.intunewin` package.

1. Download `IntuneWinAppUtil.exe` from the [Microsoft Win32 Content Prep Tool releases page](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases).

2. Create a staging folder and copy both scripts into it:

   ```
   C:\staging\SCA-Deploy\
       Deploy-SecureContacts.ps1
       Detect-SecureContacts.ps1
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
   | Version | _(leave blank — script always installs latest)_ |

## Step 3 — Configure install and uninstall commands

### Install command

```
powershell.exe -ExecutionPolicy Bypass -File Deploy-SecureContacts.ps1
```

If your environment needs a GitHub API token (see `Deploy-SecureContacts.ps1` for when this applies):

```
powershell.exe -ExecutionPolicy Bypass -File Deploy-SecureContacts.ps1 -GitHubToken "github_pat_xxx"
```

The Intune portal encrypts the install command — the token is not visible to end users.

### Uninstall command

The MSI product code changes with every release build, so a static product code in the uninstall command would go stale after the first update. Use this dynamic one-liner instead — it looks up the installed product code from the registry at uninstall time:

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
4. Check the install log if needed: `%TEMP%\SecureContacts_v*_install.log` (kept on failure only). When the script runs from Intune as `SYSTEM`, `%TEMP%` refers to the system temp directory, typically `C:\Windows\Temp`.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (installed, updated, or already up to date) |
| 3010 | Success — reboot required to complete installation |
| 1603 | Fatal failure — download error, hash mismatch, or MSI error |
| Other | MSI exit code propagated as-is |

Confirm that the Intune app return code mapping treats `3010` as a soft reboot or success condition in your tenant.

## Notes

- **Auto-update:** Because the install script always fetches the latest GitHub release, re-running the assignment (or increasing the required version in `Detect-SecureContacts.ps1`) is sufficient to trigger an update — no new `.intunewin` package needed.
- **Internet access:** The deploy script calls `api.github.com` and downloads from `objects.githubusercontent.com`. Ensure these are reachable from managed devices. If all devices share a single egress IP, add a GitHub API token to avoid the 60 requests/hour rate limit — see `Deploy-SecureContacts.ps1` for instructions.
- **Running app instances:** The deployment script stops running Secure Contacts processes before upgrade so MSI updates are less likely to fail because of locked files.

## Related files

- [`Deploy-SecureContacts.ps1`](Deploy-SecureContacts.ps1) — install/update script (see inline documentation for all parameters)
- [`Detect-SecureContacts.ps1`](Detect-SecureContacts.ps1) — detection script (update `$MinimumVersion` before deploying)
- [`SCA-Intune-Config-Manual-Win.md`](SCA-Intune-Config-Manual-Win.md) — policy configuration guide (run after app deployment)

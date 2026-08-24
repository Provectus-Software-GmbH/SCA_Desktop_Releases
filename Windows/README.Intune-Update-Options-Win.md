# Secure Contacts - Windows Intune Update Options

This guide compares the supported Windows update approaches for Secure Contacts. Choose one operating model for each Intune app and keep its install command, detection rule, and release process aligned.

## Choose an update path

| Path | Best for | Where the decision happens | Tradeoff |
|---|---|---|---|
| Organization-owned Graph publishing | Centralized, auditable release approval and publishing | Organization-owned CI calls Microsoft Graph to update an existing Intune app | Requires CI maintenance, Graph permissions, protected credentials, and approvals |
| Packaged-local MSI mode | Controlled change management or restricted endpoint network access | Administrator creates and assigns a new `.intunewin` package | Each MSI update requires a new package or SCCM/MECM content revision |
| Intune-managed GitHub release mode | Low packaging effort and automatic tracking of the latest eligible release | Intune runs dynamic detection on the device; Intune invokes the install command when non-compliant | Devices need access to GitHub and follow the latest eligible release |

The first path is the enterprise-recommended option for centralized release control, approval, auditability, and deployment-ring promotion. The second path is the controlled package-based option. The third path is the convenience-oriented Intune Win32 deployment mode. GitHub Actions and Azure DevOps are alternative CI implementations of the first path, not additional update paths.

## Path 1: Organization-owned Graph publishing

Use the shared publisher to stage, validate, package, and optionally create or update an Intune Win32 app with a signed MSI:

- Publisher reference: [README.Intune-Publisher-Win.md](README.Intune-Publisher-Win.md)
- Shared publisher: [Sync-SecureContactsToIntune.ps1](Scripts/Sync-SecureContactsToIntune.ps1)
- GitHub Actions guide: [README.Intune-GitHub-Actions.md](README.Intune-GitHub-Actions.md)
- Azure DevOps guide: [README.Intune-Azure-DevOps.md](README.Intune-Azure-DevOps.md)

Both CI examples support validation, read-only `whatIf`, and explicit publishing. Keep publication behind the protected production environment or equivalent Azure DevOps approval. Prefer `-AppId` for repeatable production publishing so the pipeline updates the intended existing app and does not rely on display-name matching.

The CI publisher does not assign the app to groups. Complete assignment and deployment-ring promotion through the organization's normal Intune change process.

## Path 2: Packaged-local MSI mode

Bundle the selected MSI with the install and uninstall scripts in the `.intunewin` package. Configure:

- Install: `powershell.exe -ExecutionPolicy Bypass -File Install-SecureContacts.ps1 -MsiPath ".\\SecureContacts.msi"`
- Detection: `Test-SecureContactsInstalled.ps1`
- Install behavior: `System`
- Process architecture: 64-bit

This mode removes the runtime GitHub dependency and lets administrators decide which release is packaged and assigned. Update `$MinimumVersion` in the static detection script when promoting a new minimum release.

Use this path for environments with restricted internet access, formal release rings, or a requirement that the deployed bytes are selected before assignment. The package must be rebuilt when the MSI changes.

## Path 3: Intune-managed GitHub release mode

Use these scripts together:

- Install command: [Install-SecureContacts.ps1](Scripts/Install-SecureContacts.ps1)
- Dynamic detection: [Test-SecureContactsUpToDate.ps1](Scripts/Test-SecureContactsUpToDate.ps1)
- Uninstall command: [Uninstall-SecureContacts.ps1](Scripts/Uninstall-SecureContacts.ps1)

The detection script checks the installed version against the latest eligible GitHub release. When it reports non-compliance, Intune controls the next step by invoking the configured install command. The detection script never installs the MSI itself and is not an autonomous scheduled updater.

The detection script caches the GitHub version for 24 hours. It can use a stale cache when GitHub is temporarily unavailable and assumes the installed version is compliant when no usable cache exists. This reduces the risk of repeated endpoint failures, but it also means a release may not be detected immediately.

Choose this path only when endpoints can reach `api.github.com` and `objects.githubusercontent.com`. Configure the Win32 app with:

- Install: `powershell.exe -ExecutionPolicy Bypass -File Install-SecureContacts.ps1`
- Detection: `Test-SecureContactsUpToDate.ps1`
- Install behavior: `System`
- Process architecture: 64-bit

See [README.Intune-Win32-Deploy-Win.md](README.Intune-Win32-Deploy-Win.md) for complete packaging and Intune portal instructions.

## Decision guidance

| Requirement | Recommended path |
|---|---|
| Central audit trail and automated Intune publishing | Organization-owned Graph publishing |
| Explicit approval before each release | Organization-owned Graph publishing or packaged-local MSI mode |
| Reuse one verified MSI across deployment rings | Organization-owned Graph publishing or packaged-local MSI mode |
| No endpoint internet access to GitHub | Packaged-local MSI mode |
| Automatically track the latest eligible release with minimal packaging | Intune-managed GitHub release mode |

Do not combine dynamic GitHub detection with packaged-local installation. The dynamic detection script compares against GitHub, while the static detection script compares against the administrator-selected minimum version.

## Related documentation

- [README.Intune-Win32-Deploy-Win.md](README.Intune-Win32-Deploy-Win.md) - Win32 packaging, installation, detection, uninstall, and device validation
- [README.Intune-Publisher-Win.md](README.Intune-Publisher-Win.md) - publisher script contract and manual authentication examples
- [README.Intune-GitHub-Actions.md](README.Intune-GitHub-Actions.md) - GitHub Actions implementation
- [README.Intune-Azure-DevOps.md](README.Intune-Azure-DevOps.md) - Azure DevOps implementation

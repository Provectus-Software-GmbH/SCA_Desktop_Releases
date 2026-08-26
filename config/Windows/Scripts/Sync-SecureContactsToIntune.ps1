<#
.SYNOPSIS
    Automates downloading a Windows MSI from GitHub Releases, packaging it as a Win32 app (.intunewin),
    and publishing/updating it in Microsoft Intune via Microsoft Graph API.

.DESCRIPTION
    By default, the script downloads and validates the latest eligible MSI, creates an .intunewin package,
    and writes non-secret audit artifacts. It does not authenticate to Microsoft Graph or change Intune unless
    -Publish is supplied. Release tags must use vMAJOR.MINOR.PATCH and the MSI filename must match the normalized
    release version. MSI ProductVersion is compared using its first three numeric components, so 0.8.18.0 matches
    release v0.8.18. In publish mode, Intune is queried before the MSI download and equal
    or newer versions are skipped. Use -WhatIf with -Publish to review the target action without writing the change.

.PARAMETER GitHubRepo
    GitHub repository in owner/repository format. The latest published, non-draft, non-prerelease release is used unless -ReleaseTag is supplied.

.PARAMETER ReleaseTag
    Optional exact GitHub release tag in vMAJOR.MINOR.PATCH format, for example v0.8.18. Use this to validate or publish a specific release instead of the latest release.

.PARAMETER TenantId
    Microsoft Entra tenant ID used for Graph authentication. Required only with -Publish; do not provide a dummy value for staging.

.PARAMETER ClientId
    Microsoft Entra application (service principal) ID used for Graph authentication. Required only with -Publish.

.PARAMETER ClientSecret
    Client secret value used for testing. Avoid this option in production because command-line values can be exposed in shell history or process diagnostics.

.PARAMETER ClientSecretEnvironmentVariable
    Name of the environment variable containing the client secret. Pass the variable name, not the secret value. Prefer a protected CI secret for automation.

.PARAMETER CertificateThumbprint
    Thumbprint of an existing certificate with a private key in the selected Windows certificate store. Use this for an administrator workstation or a certificate already imported by CI.

.PARAMETER CertificatePath
    Path to a PFX file containing a certificate with a private key. The script imports it into the selected store for the run and removes the imported certificate during cleanup.

.PARAMETER CertificatePassword
    SecureString password for the PFX supplied through -CertificatePath. This option is invalid without -CertificatePath.

.PARAMETER CertificateStoreLocation
    Certificate store for authentication: CurrentUser\My (recommended for CI) or LocalMachine\My (typically requires administrative rights).

.PARAMETER MsiAssetName
    Optional exact case-sensitive MSI asset name. Use this only when the selected release contains more than one MSI asset; it does not select the release version.

.PARAMETER ExpectedSha256
    Optional expected SHA-256 value used as an additional integrity check against the GitHub release digest.

.PARAMETER ExpectedSigner
    Optional text that must occur in the Authenticode signer certificate subject of the downloaded MSI.

.PARAMETER AppId
    Existing Intune Win32 app ID to update. Prefer this over display-name matching for repeatable publishing.

.PARAMETER AppName
    Display name used when searching for an existing app or creating a new app when -AppId is not supplied.

.PARAMETER Publisher
    Publisher value written to a newly created Intune app. It is not used when updating an existing app.

.PARAMETER Description
    Description written to a newly created Intune app. It is not used when updating an existing app.

.PARAMETER IconPath
    PNG file used as the icon for a newly created Intune app. Defaults to the repository's Windows logo.

.PARAMETER ProcessingTimeoutMinutes
    Maximum number of minutes to wait for Intune to report a recognized successful processing state after upload.

.PARAMETER ArtifactOutputPath
    Directory where the non-secret manifest and generated .intunewin package are retained for audit and review.

.PARAMETER Publish
    Enables Graph authentication and the Intune create/update operation. Without this switch, the script only stages and validates the package. In publish mode, an Intune app with an equal or newer displayVersion is a successful no-op.

.EXAMPLE
    .\Sync-SecureContactsToIntune.ps1 -GitHubRepo 'owner/repository'

    Validates and packages the release without requiring Graph credentials or contacting Intune.

.EXAMPLE
    .\Sync-SecureContactsToIntune.ps1 -GitHubRepo 'owner/repository' -ReleaseTag 'v0.8.18' -Publish

    Validates and publishes a specific release. MsiAssetName is not needed when the release contains one matching MSI.

.EXAMPLE
    .\Sync-SecureContactsToIntune.ps1 -GitHubRepo 'owner/repository' -TenantId $tenantId -ClientId $clientId -CertificateThumbprint $thumbprint -AppId $appId -Publish

    Publishes using a certificate already installed in the Windows certificate store.

.EXAMPLE
    .\Sync-SecureContactsToIntune.ps1 -GitHubRepo 'owner/repository' -TenantId $env:INTUNE_TENANT_ID -ClientId $env:INTUNE_CLIENT_ID -ClientSecretEnvironmentVariable 'INTUNE_CLIENT_SECRET' -AppId $env:INTUNE_APP_ID -Publish

    Publishes using a client secret held in a protected environment variable.

.EXAMPLE
    $password = ConvertTo-SecureString $env:INTUNE_CERTIFICATE_PASSWORD -AsPlainText -Force
    .\Sync-SecureContactsToIntune.ps1 -GitHubRepo 'owner/repository' -TenantId $env:INTUNE_TENANT_ID -ClientId $env:INTUNE_CLIENT_ID -CertificatePath $env:INTUNE_CERTIFICATE_PATH -CertificatePassword $password -AppId $env:INTUNE_APP_ID -Publish

    Imports a protected PFX for the run, publishes the package, and removes the imported certificate during cleanup.

.NOTES
    Required Entra ID Application Permissions:
    - DeviceManagementApps.ReadWrite.All

    TenantId and ClientId are required only when -Publish is specified. They are not needed for validation-only staging.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)] [ValidatePattern('^[^/ ]+/[^/ ]+$')] [string]$GitHubRepo,
    [Parameter(Mandatory = $false)] [ValidatePattern('^v\d+\.\d+\.\d+$')] [string]$ReleaseTag,
    [Parameter(Mandatory = $false)] [string]$TenantId,
    [Parameter(Mandatory = $false)] [string]$ClientId,
    [Parameter(Mandatory = $false)] [string]$ClientSecret,
    [Parameter(Mandatory = $false)] [string]$ClientSecretEnvironmentVariable,
    [Parameter(Mandatory = $false)] [ValidatePattern('^[a-fA-F0-9]{40}$')] [string]$CertificateThumbprint,
    [Parameter(Mandatory = $false)] [string]$CertificatePath,
    [Parameter(Mandatory = $false)] [System.Security.SecureString]$CertificatePassword,
    [Parameter(Mandatory = $false)] [ValidateSet('CurrentUser\My', 'LocalMachine\My')] [string]$CertificateStoreLocation = 'CurrentUser\My',
    [Parameter(Mandatory = $false)] [string]$MsiAssetName,
    [Parameter(Mandatory = $false)] [ValidatePattern('^[a-fA-F0-9]{64}$')] [string]$ExpectedSha256,
    [Parameter(Mandatory = $false)] [string]$ExpectedSigner,
    [Parameter(Mandatory = $false)] [string]$AppId,
    [Parameter(Mandatory = $false)] [string]$AppName = 'Secure Contacts Desktop Enterprise',
    [Parameter(Mandatory = $false)] [string]$Publisher = 'Provectus Software GmbH',
    [Parameter(Mandatory = $false)] [string]$Description = 'Secure Contacts enterprise desktop app.',
    [Parameter(Mandatory = $false)] [string]$IconPath = (Join-Path $PSScriptRoot 'icon.png'),
    [Parameter(Mandatory = $false)] [ValidateRange(1, 60)] [int]$ProcessingTimeoutMinutes = 15,
    [Parameter(Mandatory = $false)] [string]$ArtifactOutputPath = (Join-Path (Get-Location) 'SecureContacts-Intune-Artifacts'),
    [Parameter(Mandatory = $false)] [switch]$Publish
)

# Fail fast: a partially validated package must never reach Intune.
$ErrorActionPreference = "Stop"
$moduleName = 'IntuneWin32App'
$moduleVersion = '1.5.0'
$workDir = $null
$importedCertificateThumbprint = $null
$targetApp = $null
$previousIntuneVersion = $null
$releaseVersion = $null
$updateDecision = 'ValidationOnly'
$publicationPerformed = $false

function Write-Status {
    param ([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[Secure Contacts] $Message" -ForegroundColor Cyan
}

function Assert-Command {
    # Check dependencies explicitly so a missing cmdlet cannot silently change the workflow.
    param ([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' is unavailable. Install/import module '$moduleName'."
    }
}

function Get-AssetChecksum {
    # GitHub exposes a digest on newer APIs; older releases use a separate checksum asset.
    param ([Parameter(Mandatory = $true)]$Release, [Parameter(Mandatory = $true)]$MsiAsset)
    if ($MsiAsset.PSObject.Properties.Name -contains 'digest' -and $MsiAsset.digest -match '^sha256:([a-fA-F0-9]{64})$') {
        return $Matches[1].ToLowerInvariant()
    }
    $checksumAsset = @($Release.assets | Where-Object {
        $_.name -eq "$($MsiAsset.name).sha256" -or $_.name -eq "$($MsiAsset.name).sha256.txt"
    })
    if ($checksumAsset.Count -ne 1) {
        throw "GitHub asset '$($MsiAsset.name)' has no unique SHA-256 digest. Supply -ExpectedSha256 or publish a matching .sha256 asset."
    }
    $raw = Invoke-WebRequest -Uri $checksumAsset[0].browser_download_url -UseBasicParsing
    $content = $raw.Content
    if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    if ($content.Trim() -notmatch '(?i)\b([a-f0-9]{64})\b') { throw "Checksum asset '$($checksumAsset[0].name)' does not contain a SHA-256 value." }
    return $Matches[1].ToLowerInvariant()
}

function Get-MsiIdentity {
    # Read identity from the MSI database so detection rules describe the downloaded package.
    param ([Parameter(Mandatory = $true)][string]$Path)
    $installer = New-Object -ComObject WindowsInstaller.Installer
    $database = $null; $view = $null
    try {
        $database = $installer.OpenDatabase($Path, 0)
        $view = $database.OpenView('SELECT `Property`, `Value` FROM `Property`')
        $view.Execute(); $values = @{}
        while ($record = $view.Fetch()) {
            if ($record.StringData(1) -in @('ProductCode', 'ProductName', 'ProductVersion')) {
                $values[$record.StringData(1)] = $record.StringData(2)
            }
        }
        if (-not $values.ProductCode -or -not $values.ProductName -or -not $values.ProductVersion) { throw 'MSI is missing ProductCode, ProductName, or ProductVersion properties.' }
        [pscustomobject]@{ ProductCode = $values.ProductCode; ProductName = $values.ProductName; ProductVersion = $values.ProductVersion }
    }
    finally {
        if ($view) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($view) }
        if ($database) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($database) }
        if ($installer) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($installer) }
    }
}

function Connect-Intune {
    # Authentication is deliberately isolated from staging: validation-only runs need no Graph access.
    if (-not $TenantId -or -not $ClientId) {
        throw 'TenantId and ClientId are required when -Publish is specified.'
    }
    if ($ClientSecretEnvironmentVariable) {
        if ($ClientSecret) { throw 'Specify either -ClientSecret or -ClientSecretEnvironmentVariable, not both.' }
        $ClientSecret = [Environment]::GetEnvironmentVariable($ClientSecretEnvironmentVariable)
        if (-not $ClientSecret) { throw "Environment variable '$ClientSecretEnvironmentVariable' is empty or unavailable." }
    }
    if ($CertificatePath -and $CertificateThumbprint) {
        throw 'Specify -CertificatePath, or use -CertificateThumbprint with an already-installed certificate.'
    }
    if ($CertificatePassword -and -not $CertificatePath) {
        throw '-CertificatePassword can only be used together with -CertificatePath.'
    }
    if ($CertificatePath) {
        if (-not (Test-Path -LiteralPath $CertificatePath -PathType Leaf)) { throw "Certificate file '$CertificatePath' was not found." }
        $importParameters = @{ FilePath = (Resolve-Path -LiteralPath $CertificatePath).Path; CertStoreLocation = "Cert:\$CertificateStoreLocation" }
        if ($CertificatePassword) { $importParameters.Password = $CertificatePassword }
        $certificate = @(Import-PfxCertificate @importParameters) | Where-Object HasPrivateKey | Select-Object -First 1
        if (-not $certificate -or -not $certificate.HasPrivateKey) { throw 'The imported certificate does not contain a private key.' }
        $script:importedCertificateThumbprint = $certificate.Thumbprint
        $CertificateThumbprint = $certificate.Thumbprint
    }
    if ([bool]$ClientSecret -eq [bool]$CertificateThumbprint) { throw 'Specify exactly one authentication method: -ClientSecret, -ClientSecretEnvironmentVariable, -CertificateThumbprint, or -CertificatePath.' }
    Assert-Command -Name 'Connect-MSIntuneGraph'
    if ($CertificateThumbprint) {
        $certificatePath = "Cert:\$CertificateStoreLocation\$CertificateThumbprint"
        $certificate = Get-Item -LiteralPath $certificatePath -ErrorAction SilentlyContinue
        if (-not $certificate) { throw "Certificate '$CertificateThumbprint' was not found at $certificatePath." }
        if (-not $certificate.HasPrivateKey) { throw "Certificate '$CertificateThumbprint' does not contain a private key." }
        if ($certificate.NotAfter -le (Get-Date)) { throw "Certificate '$CertificateThumbprint' is expired." }
        [void](Connect-MSIntuneGraph -TenantID $TenantId -ClientID $ClientId -ClientCert $certificate)
    }
    else {
        Write-Warning 'Client-secret authentication is intended for testing. Use certificate authentication in production.'
        [void](Connect-MSIntuneGraph -TenantID $TenantId -ClientID $ClientId -ClientSecret $ClientSecret)
    }
}

function Wait-IntuneAppProcessing {
    # Upload commands can return before Intune finishes processing the content.
    param ([Parameter(Mandatory = $true)][string]$Id)
    $deadline = (Get-Date).AddMinutes($ProcessingTimeoutMinutes)
    $nextStatusUpdate = Get-Date
    Write-Status "Waiting for Intune to finish processing app '$Id' (timeout: $ProcessingTimeoutMinutes minute(s))."
    do {
        $app = @(Get-IntuneWin32App -ID $Id)
        if ($app.Count -ne 1) { throw "Unable to verify Intune app '$Id' after publication." }
        $states = @($app[0].publishingState, $app[0].uploadState) | Where-Object { $_ } | ForEach-Object { $_.ToString().ToLowerInvariant() }
        if ($states.Count -eq 0) { throw "Intune returned no processing state for app '$Id'." }
        if ($states | Where-Object { $_ -in @('failed', 'error', 'failure') }) { throw "Intune reported a failed processing state for app '$Id': $($states -join ', ')." }
        if ($states | Where-Object { $_ -in @('success', 'succeeded', 'completed', 'published', 'ready') }) {
            Write-Status "Intune processing completed for app '$Id'."
            return $app[0]
        }
        if ($states | Where-Object { $_ -notin @('processing', 'pending', 'inprogress', 'uploading') }) { throw "Intune returned an unrecognized processing state for app '$Id': $($states -join ', ')." }
        if ((Get-Date) -ge $nextStatusUpdate) {
            Write-Status "Intune is still processing app '$Id' (state: $($states -join ', '))."
            $nextStatusUpdate = (Get-Date).AddSeconds(45)
        }
        [Threading.Thread]::Sleep(15000)
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for Intune app '$Id' to finish processing."
}

function ConvertTo-ReleaseVersion {
    # GitHub tags include a leading v; comparison must use numeric version semantics, not string ordering.
    param ([Parameter(Mandatory = $true)][string]$Tag)
    if ($Tag -notmatch '^v(\d+)\.(\d+)\.(\d+)$') {
        throw "Release tag '$Tag' is invalid. Expected format vMAJOR.MINOR.PATCH, for example v1.3.11."
    }
    return [version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
}

function ConvertTo-ComparableVersion {
    # MSI and registry versions may contain a fourth revision component; compare the release components only.
    param ([Parameter(Mandatory = $true)][string]$VersionString)
    $normalizedVersionString = $VersionString.Trim() -replace '^v', ''
    if ($normalizedVersionString -notmatch '^\d+\.\d+\.\d+(?:\.\d+)?$') {
        throw "Version '$VersionString' is invalid. Expected three or four numeric components."
    }
    $parsedVersion = [version]$normalizedVersionString
    return [version]::new($parsedVersion.Major, $parsedVersion.Minor, $parsedVersion.Build)
}

function Get-IntuneAppVersion {
    # Missing version metadata is unsafe to treat as an old version.
    param ([Parameter(Mandatory = $true)]$App)
    if (-not $App.displayVersion -or $App.displayVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Intune app '$($App.id)' has no usable displayVersion. Refusing to publish without a version comparison."
    }
    return [version]$App.displayVersion
}

try {
    # The module is pinned to a known minimum because its authentication and upload cmdlets are the API boundary.
    Write-Status "Checking required module '$moduleName' (minimum version $moduleVersion)."
    $installedModule = @(Get-Module -ListAvailable -Name $moduleName | Where-Object { $_.Version -ge [version]$moduleVersion } | Sort-Object Version -Descending | Select-Object -First 1)
    if ($installedModule.Count -eq 0) {
        throw "Module '$moduleName' version $moduleVersion or newer is required. Install it with: Install-Module -Name $moduleName -RequiredVersion $moduleVersion -Scope CurrentUser"
    }
    Import-Module -Name $moduleName -MinimumVersion ([version]$moduleVersion)
    @('New-IntuneWin32AppPackage', 'New-IntuneWin32AppDetectionRuleMSI', 'New-IntuneWin32AppRequirementRule') | ForEach-Object { Assert-Command -Name $_ }
    Write-Status "Module '$moduleName' $($installedModule[0].Version) is available."

    # Use a unique workspace so concurrent runs cannot delete or reuse one another's package files.
    $workDir = Join-Path ([IO.Path]::GetTempPath()) ('SecureContacts-Intune-' + [guid]::NewGuid().ToString('N'))
    $sourceDir = Join-Path $workDir 'Source'; $outDir = Join-Path $workDir 'Output'
    New-Item -ItemType Directory -Path $sourceDir, $outDir -Force -WhatIf:$false | Out-Null
    $repo = $GitHubRepo.Trim()
    # Only a published GitHub release is eligible for packaging.
    $releaseEndpoint = if ($ReleaseTag) { "releases/tags/$ReleaseTag" } else { 'releases/latest' }
    Write-Status "Resolving GitHub release from '$repo'."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/$releaseEndpoint" -Method Get
    if (-not $release.tag_name -or $release.draft -or $release.prerelease) { throw 'Latest GitHub release is missing, draft, or prerelease.' }
    $releaseVersion = ConvertTo-ReleaseVersion -Tag $release.tag_name
    Write-Status "Selected release $($release.tag_name) (version $releaseVersion)."

    # Publishing checks Intune before downloading a large MSI; validation-only mode intentionally skips Graph.
    if ($Publish) {
        Write-Status 'Authenticating to Intune.'
        Connect-Intune
        if ($AppId) {
            Write-Status "Looking up Intune app '$AppId'."
        }
        else {
            Write-Status "Looking up Intune Win32 apps and matching display name '$AppName'."
        }
        $targetApps = @(
            if ($AppId) {
                Get-IntuneWin32App -ID $AppId
            }
            else {
                $allIntuneApps = @(Get-IntuneWin32App)
                Write-Status "Retrieved $($allIntuneApps.Count) Intune Win32 app(s) for local matching."
                $allIntuneApps | Where-Object {
                    [string]::Equals(([string]$_.displayName).Trim(), $AppName.Trim(), [StringComparison]::OrdinalIgnoreCase)
                }
            }
        )
        $targetAppCount = @($targetApps).Count
        Write-Status "Found $targetAppCount Intune app(s) matching the requested target."
        if ($targetAppCount -gt 1) { throw "More than one Intune app matched '$AppName'; specify -AppId." }
        if ($AppId -and $targetAppCount -eq 0) { throw "No Intune app was found with ID '$AppId'; refusing to create a different app." }
        if ($targetAppCount -eq 1) {
            $targetApp = $targetApps[0]
            $previousIntuneVersion = Get-IntuneAppVersion -App $targetApp
            if ($previousIntuneVersion -ge $releaseVersion) {
                $updateDecision = 'NoUpdateRequired'
                $artifactDir = Join-Path $ArtifactOutputPath ($release.tag_name -replace '[^a-zA-Z0-9._-]', '_')
                New-Item -ItemType Directory -Path $artifactDir -Force -WhatIf:$false | Out-Null
                [ordered]@{ Repository = $repo; ReleaseTag = $release.tag_name; ReleaseVersion = $releaseVersion.ToString(); PreviousIntuneVersion = $previousIntuneVersion.ToString(); UpdateDecision = $updateDecision; FinalAction = 'Skipped'; CreatedUtc = [DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content -Path (Join-Path $artifactDir 'manifest.json') -Encoding UTF8
                Write-Host "No update required. Intune version is $previousIntuneVersion; GitHub version is $releaseVersion." -ForegroundColor Yellow
                return
            }
            $updateDecision = 'UpdateExistingApp'
            Write-Status "Existing Intune app is at version $previousIntuneVersion; update will use $releaseVersion."
        }
        else {
            $updateDecision = 'CreateNewApp'
            Write-Status "No existing Intune app matched; a new app will be created."
        }
    }

    # Never choose the first matching file: multiple MSI assets usually represent different architectures.
    $msiAssets = @($release.assets | Where-Object { $_.name -match '(?i)\.msi$' })
    if ($MsiAssetName) { $msiAssets = @($msiAssets | Where-Object { $_.name -ceq $MsiAssetName }) }
    if ($msiAssets.Count -ne 1) { throw "Expected exactly one MSI asset; found $($msiAssets.Count). Specify the exact name with -MsiAssetName." }
    $msiAsset = $msiAssets[0]; $msiPath = Join-Path $sourceDir $msiAsset.name
    $expectedMsiName = "SecureContacts-$releaseVersion.msi"
    if ($msiAsset.name -ne $expectedMsiName) { throw "MSI asset '$($msiAsset.name)' does not match expected asset name '$expectedMsiName' for release '$($release.tag_name)'." }
    Write-Status "Downloading MSI '$($msiAsset.name)'."
    Invoke-WebRequest -Uri $msiAsset.browser_download_url -OutFile $msiPath -UseBasicParsing
    Write-Status 'Validating MSI checksum, signature, identity, and version.'
    $actualSha256 = (Get-FileHash -Path $msiPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $releaseSha256 = Get-AssetChecksum -Release $release -MsiAsset $msiAsset
    if ($ExpectedSha256 -and $ExpectedSha256.ToLowerInvariant() -ne $releaseSha256) { throw 'Expected SHA-256 does not match the GitHub release digest.' }
    if ($actualSha256 -ne $releaseSha256) { throw "Downloaded MSI SHA-256 '$actualSha256' does not match release SHA-256 '$releaseSha256'." }

    # Hash validation proves integrity; Authenticode validation establishes the expected software publisher.
    $signature = Get-AuthenticodeSignature -FilePath $msiPath
    if ($signature.Status -ne 'Valid') { throw "MSI Authenticode signature status is '$($signature.Status)'; a valid signature is required." }
    if ($ExpectedSigner -and $signature.SignerCertificate.Subject -notlike "*$ExpectedSigner*") { throw "MSI signer '$($signature.SignerCertificate.Subject)' does not match expected signer '$ExpectedSigner'." }
    $msiIdentity = Get-MsiIdentity -Path $msiPath
    $msiComparableVersion = ConvertTo-ComparableVersion -VersionString $msiIdentity.ProductVersion
    if ($msiComparableVersion -ne $releaseVersion) { throw "MSI ProductVersion '$($msiIdentity.ProductVersion)' does not match release version '$releaseVersion'." }
    Write-Status "Packaging '$($msiAsset.name)' as an Intune Win32 app."
    $package = New-IntuneWin32AppPackage -SourceFolder $sourceDir -SetupFile $msiAsset.name -OutputFolder $outDir -Force
    $intuneWinPath = $package.Path
    if (-not (Test-Path $intuneWinPath)) { throw 'Packaging did not produce an .intunewin file.' }

    $finalAction = if (-not $Publish) { 'Validated' } elseif ($targetApp) { 'UpdateRequested' } else { 'CreateRequested' }
    $manifest = [ordered]@{ Repository = $repo; ReleaseTag = $release.tag_name; ReleaseVersion = $releaseVersion.ToString(); AssetName = $msiAsset.name; Sha256 = $actualSha256; Signer = $signature.SignerCertificate.Subject; ProductCode = $msiIdentity.ProductCode; ProductName = $msiIdentity.ProductName; ProductVersion = $msiIdentity.ProductVersion; PreviousIntuneVersion = if ($previousIntuneVersion) { $previousIntuneVersion.ToString() } else { $null }; UpdateDecision = $updateDecision; FinalAction = $finalAction; PackageName = [IO.Path]::GetFileName($intuneWinPath); Module = $moduleName; ModuleVersion = (Get-Module $moduleName).Version.ToString(); CreatedUtc = [DateTime]::UtcNow.ToString('o') }
    # Keep audit evidence outside the disposable workspace, but exclude all credentials by construction.
    $artifactDir = Join-Path $ArtifactOutputPath ($release.tag_name -replace '[^a-zA-Z0-9._-]', '_')
    New-Item -ItemType Directory -Path $artifactDir -Force -WhatIf:$false | Out-Null
    $manifestPath = Join-Path $artifactDir 'manifest.json'
    $manifest | ConvertTo-Json | Set-Content -Path $manifestPath -Encoding UTF8
    Copy-Item -Path $intuneWinPath -Destination $artifactDir -Force
    Write-Status "Wrote validation artifacts to '$artifactDir'."
    Write-Host "Validated $($msiIdentity.ProductName) $($msiIdentity.ProductVersion); audit artifacts written to $artifactDir" -ForegroundColor Green

    # Staging is the safe default. Graph authentication and writes begin only after explicit approval.
    if (-not $Publish) {
        Write-Status 'Validation-only run complete; no Intune changes were requested.'
        return
    }
    # An explicit ID is preferred; name matching is accepted only when it is unambiguous.
    $apps = if ($targetApp) { @($targetApp) } else { @() }
    # Existing apps receive new content; otherwise create a new app with MSI-based detection.
    if ($apps.Count -eq 1) {
        Write-Status "Requesting package update for existing Intune app '$($apps[0].id)'."
        if ($PSCmdlet.ShouldProcess("Intune app $($apps[0].id)", 'Update package')) {
            [void](Update-IntuneWin32AppPackageFile -ID $apps[0].id -FilePath $intuneWinPath)
            $publicationPerformed = $true
            Wait-IntuneAppProcessing -Id $apps[0].id | Out-Null
        }
    }
    else {
        Write-Status "Requesting creation of Intune app '$AppName'."
        $detectionRule = New-IntuneWin32AppDetectionRuleMSI `
            -ProductCode $msiIdentity.ProductCode `
            -ProductVersionOperator 'greaterThanOrEqual' `
            -ProductVersion $msiIdentity.ProductVersion
        $requirementRule = New-IntuneWin32AppRequirementRule -Architecture 'x64' -MinimumSupportedWindowsRelease 'W10_1909'
        if (-not (Test-Path -LiteralPath $IconPath -PathType Leaf)) {
            throw "Icon file '$IconPath' was not found. Supply a valid PNG path with -IconPath."
        }
        $icon = New-IntuneWin32AppIcon -FilePath $IconPath
        if ($PSCmdlet.ShouldProcess("Intune app $AppName", 'Create app')) {
            $createdApp = Add-IntuneWin32App `
                -FilePath $intuneWinPath `
                -DisplayName $AppName `
                -Publisher $Publisher `
                -Description $Description `
                -DetectionRule $detectionRule `
                -RequirementRule $requirementRule `
                -AppVersion $releaseVersion.ToString() `
                -Developer $Publisher `
                -InstallExperience 'system' `
                -RestartBehavior 'suppress' `
                -UnattendedInstall `
                -UnattendedUninstall `
                -Icon $icon
            if (-not $createdApp.id) { throw 'Intune create completed without returning an app ID; processing cannot be verified.' }
            $publicationPerformed = $true
            Wait-IntuneAppProcessing -Id $createdApp.id | Out-Null
        }
    }
    if ($publicationPerformed) {
        Write-Host 'Intune publication request completed. Confirm processing in Intune before assigning the app.' -ForegroundColor Green
    }
    else {
        Write-Status 'WhatIf prevented the Intune write; no publication was performed.'
    }
}
finally {
    # Package inputs and temporary decrypted content are removed even when validation or upload fails.
    if ($workDir -and (Test-Path $workDir)) { Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue }
    if ($importedCertificateThumbprint) {
        Remove-Item -LiteralPath "Cert:\$CertificateStoreLocation\$importedCertificateThumbprint" -Force -ErrorAction SilentlyContinue
    }
}
# Requires -Version 5.1
<#
.SYNOPSIS
    Custom Intune Win32 App Detection Script for Secure Contacts.

.DESCRIPTION
    Checks HKLM Uninstall keys (64-bit and 32-bit/WOW6432Node) for Secure Contacts,
    then compares the installed version to the latest GitHub release version.

    The script caches the latest known GitHub version in ProgramData to reduce API calls.
    If GitHub is temporarily unavailable, the script falls back to stale cache data when
    available and only fails open when no cache can be used.

    Optional:
    -GitHubToken can be provided to increase GitHub API rate limits (PAT for public repo read).

    Intune detection semantics used here:
    - Exit code 0 = Detected/Compliant (installed and up to date)
    - Non-zero exit code = Not detected/Non-compliant (triggers install or update)
#>

[CmdletBinding()]
param(
    [string]$AppName = "Secure Contacts",
    [string]$GitHubToken = ""
)

$ErrorActionPreference = "Stop"

# --------------------------------------------------
# Configuration
# --------------------------------------------------

$RepoOwner = "Provectus-Software-GmbH"
$RepoName  = "SCA_Desktop_Releases"
$RequiredInstallerPattern = "*.msi"

$CacheDirectory = Join-Path $env:ProgramData "SecureContacts"
$CacheFile      = Join-Path $CacheDirectory "github-version-cache.json"

# Cache lifetime in hours before re-checking GitHub for the latest version
$CacheLifetimeHours = 24 
# Timeout for GitHub API requests in seconds
$GitHubTimeoutSec   = 10

# --------------------------------------------------
# Helper Functions
# --------------------------------------------------

function Normalize-VersionForComparison {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionString
    )

    $parsedVersion = [version]($VersionString -replace '^v', '')
    $build = if ($parsedVersion.Build -ge 0) { $parsedVersion.Build } else { 0 }

    return [version]"$($parsedVersion.Major).$($parsedVersion.Minor).$build"
}

function Get-InstalledVersion {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $app = Get-ItemProperty $paths -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -eq $AppName
        } |
        Select-Object -First 1

    if (-not $app) {
        return $null
    }

    try {
        return Normalize-VersionForComparison -VersionString $app.DisplayVersion
    }
    catch {
        return $null
    }
}

function Get-CachedVersion {
    if (-not (Test-Path $CacheFile)) {
        return $null
    }

    try {

        $cache = Get-Content $CacheFile -Raw | ConvertFrom-Json

        $timestamp = [DateTime]$cache.Timestamp

        $age = (Get-Date).ToUniversalTime() - $timestamp

        if ($age.TotalHours -gt $CacheLifetimeHours) {
            return $null
        }

        return $cache
    }
    catch {
        return $null
    }
}

function Get-StaleCachedVersion {
    if (-not (Test-Path $CacheFile)) {
        return $null
    }

    try {
        return Get-Content $CacheFile -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Save-VersionCache {
    param(
        [string]$Version
    )

    if (-not (Test-Path $CacheDirectory)) {
        New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
    }

    @{
        Version   = $Version
        Timestamp = (Get-Date).ToUniversalTime().ToString("o")
    } |
    ConvertTo-Json |
    Set-Content $CacheFile -Encoding UTF8
}

function Get-LatestGitHubVersion {
    $uri = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"

    $headers = @{
        "User-Agent" = "SecureContacts-Detection"
    }

    if ($GitHubToken) {
        $headers["Authorization"] = "Bearer $GitHubToken"
    }

    $response = Invoke-RestMethod `
        -Uri $uri `
        -Method Get `
        -TimeoutSec $GitHubTimeoutSec `
        -Headers $headers

    $msiAsset = $response.assets | Where-Object { $_.name -like $RequiredInstallerPattern } | Select-Object -First 1
    if (-not $msiAsset) {
        throw "No installer matching '$RequiredInstallerPattern' found in latest GitHub release."
    }

    $normalizedVersion = Normalize-VersionForComparison -VersionString $response.tag_name

    Save-VersionCache -Version $normalizedVersion.ToString()

    return $normalizedVersion
}

# --------------------------------------------------
# Detection Logic
# --------------------------------------------------

$installedVersion = Get-InstalledVersion

if (-not $installedVersion) {
    Write-Output "Secure Contacts not installed."
    exit 1
}

$latestVersion = $null

# Try cache first
$cachedVersion = Get-CachedVersion

if ($cachedVersion) {
    try {
        $latestVersion = Normalize-VersionForComparison -VersionString $cachedVersion.Version
    }
    catch {
        $latestVersion = $null
    }
}

# Cache missing or expired -> GitHub lookup
if (-not $latestVersion) {
    try {

        $latestVersion = Get-LatestGitHubVersion
    }
    catch {
        $staleCache = Get-StaleCachedVersion

        if ($staleCache) {
            try {
                $latestVersion = Normalize-VersionForComparison -VersionString $staleCache.Version
                Write-Output "GitHub check failed. Using stale cached version."
            }
            catch {
                $latestVersion = $null
            }
        }

        if ($latestVersion) {
            # Continue with version comparison using stale cached value.
        }
        else {
            Write-Output "GitHub check failed and no usable cache found. Assuming installed version is compliant."
            Write-Output "Installed Version: $installedVersion"
            exit 0
        }
    }
}

# Version Comparison
if ($installedVersion -lt $latestVersion) {
    Write-Output "Update available."
    Write-Output "Installed: $installedVersion"
    Write-Output "Latest:    $latestVersion"
    exit 1
}

Write-Output "Secure Contacts detected."
Write-Output "Installed Version: $installedVersion"
exit 0
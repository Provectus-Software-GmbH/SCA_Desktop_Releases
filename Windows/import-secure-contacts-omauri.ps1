param(
  [string]$ProfileJsonPath = ".\\secure-contacts.intune-omauri-profile.json",
  [string]$AdmxPath = ".\\secure-contacts.admx",
  [switch]$UseBeta
)

# Requires: Microsoft.Graph PowerShell SDK
# Install once: Install-Module Microsoft.Graph -Scope CurrentUser

$requiredScopes = @(
  "DeviceManagementConfiguration.ReadWrite.All"
)

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop

if (-not (Test-Path $ProfileJsonPath)) {
  throw "Profile JSON not found: $ProfileJsonPath"
}

if (-not (Test-Path $AdmxPath)) {
  throw "ADMX file not found: $AdmxPath"
}

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes $requiredScopes | Out-Null

$profile = Get-Content -Raw -Path $ProfileJsonPath | ConvertFrom-Json -Depth 100
$admxXml = Get-Content -Raw -Path $AdmxPath

# Replace placeholder with real ADMX content.
$admxSetting = $profile.omaSettings | Where-Object { $_.omaUri -like "*/ADMXInstall/*" } | Select-Object -First 1
if (-not $admxSetting) {
  throw "Could not find ADMXInstall setting in profile JSON."
}
$admxSetting.value = $admxXml

$uri = if ($UseBeta) {
  "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
} else {
  "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations"
}

$body = $profile | ConvertTo-Json -Depth 100

Write-Host "Creating Intune custom profile..." -ForegroundColor Cyan
$result = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType "application/json"

Write-Host "Created profile:" -ForegroundColor Green
Write-Host ("- id: " + $result.id)
Write-Host ("- displayName: " + $result.displayName)
Write-Host ""
Write-Host "Next step: assign this profile to a DEVICE group in Intune (Machine-scope ADMX policies)." -ForegroundColor Yellow

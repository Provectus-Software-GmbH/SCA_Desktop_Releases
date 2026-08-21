# Intune OMA-URI Import (Graph)

Intune portal does not support uploading a single JSON file to bulk-create custom OMA-URI rows.
Use the included Graph payload + PowerShell importer.

## Files

- secure-contacts.intune-omauri-profile.json
  - Graph payload template for a Windows custom configuration profile.
  - Blank template version for production use.
- secure-contacts.intune-omauri-profile.ready.json
  - Ready-to-use version with the current `secure-contacts.admx` content already embedded.
  - Convenience artifact for admins who want the ADMXInstall payload pre-resolved.
- secure-contacts.intune-omauri-profile.example.json
  - Example version with filled sample values for reference only.
- import-secure-contacts-omauri.ps1
  - Creates the profile in Intune via Microsoft Graph.
  - Can also write a resolved JSON file before upload.
- ..\ADMX\secure-contacts.admx
  - Required for ADMX ingestion setting value.
- ..\ADMX\secure-contacts.adml
  - Matching locale resource file required by ADMX-backed policy processing.

## Usage

From this folder:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
.\import-secure-contacts-omauri.ps1
```

Generate or refresh the ready-to-use JSON artifact without calling Microsoft Graph:

```powershell
.\import-secure-contacts-omauri.ps1 -ResolvedProfileJsonPath .\secure-contacts.intune-omauri-profile.ready.json -WriteResolvedProfileOnly
```

Optional (beta endpoint):

```powershell
.\import-secure-contacts-omauri.ps1 -UseBeta
```

## What it creates

- One ADMX ingest OMA-URI setting (value is read from ..\ADMX\secure-contacts.admx at runtime)
- Eleven Secure Contacts policy OMA-URI settings

## After creation

1. Open Intune Admin Center -> Devices -> Configuration profiles.
2. Find profile: "Secure Contacts - OMA URI (Device)".
3. Assign to a DEVICE group (ADMX class in your file is Machine).
4. Verify on client under:
  - HKLM\\Software\\Policies\\ProvectusSoftwareGmbH\\SecureContactsDesktop

## Important

- The JSON file is a Graph payload template, not a file you can upload directly in the Intune UI.
- `secure-contacts.intune-omauri-profile.ready.json` is the convenience version with ADMX content already embedded.
- `secure-contacts.intune-omauri-profile.json` remains the canonical editable template.
- Upload/associate the matching ADML resource when Intune prompts for ADMX localization metadata.
- Replace sample values in the JSON with your real production values before importing.

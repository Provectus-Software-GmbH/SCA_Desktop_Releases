# Intune OMA-URI Import (Graph)

Intune portal does not support uploading a single JSON file to bulk-create custom OMA-URI rows.
Use the included Graph payload + PowerShell importer.

## Files

- secure-contacts.intune-omauri-profile.json
  - Graph payload template for a Windows custom configuration profile.
  - Blank template version for production use.
- secure-contacts.intune-omauri-profile.example.json
  - Example version with filled sample values for reference only.
- import-secure-contacts-omauri.ps1
  - Creates the profile in Intune via Microsoft Graph.
- secure-contacts.admx
  - Required for ADMX ingestion setting value.
- secure-contacts.adml
  - Matching locale resource file required by ADMX-backed policy processing.

## Usage

From this folder:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
.\import-secure-contacts-omauri.ps1
```

Optional (beta endpoint):

```powershell
.\import-secure-contacts-omauri.ps1 -UseBeta
```

## What it creates

- One ADMX ingest OMA-URI setting (value is read from secure-contacts.admx at runtime)
- Eleven Secure Contacts policy OMA-URI settings

## After creation

1. Open Intune Admin Center -> Devices -> Configuration profiles.
2. Find profile: "Secure Contacts - OMA URI (Device)".
3. Assign to a DEVICE group (ADMX class in your file is Machine).
4. Verify on client under:
  - HKLM\\Software\\Policies\\ProvectusSoftwareGmbH\\SecureContactsDesktop

## Important

- The JSON file is a Graph payload template, not a file you can upload directly in the Intune UI.
- Upload/associate the matching ADML resource when Intune prompts for ADMX localization metadata.
- Replace sample values in the JSON with your real production values before importing.

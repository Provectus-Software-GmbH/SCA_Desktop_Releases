# Secure Contacts Intune Configuration Manual (Windows)

This guide shows how to configure Secure Contacts for Windows in Microsoft Intune using two supported setup paths.

## Scope

This manual focuses on configuration and rollout, not policy design.
It applies to the Windows app configuration path only (ADMX/ADML and Windows Policy CSP OMA-URI).

You can configure the app using either of these methods:

- Method A: Import ADMX/ADML and configure settings through the Intune Administrative Templates UI.
- Method B: Use Custom OMA-URI settings (manual rows or the provided JSON + PowerShell importer).

## Method A: ADMX/ADML Imported Administrative Templates

Use this when you want a policy UI experience in Intune without managing OMA-URI rows directly.

### Required files

- `secure-contacts.admx`
- `secure-contacts.adml`

Important:
- `secure-contacts.admx` and `secure-contacts.adml` define policy schema/UI labels.
- Enter your production values directly in the Intune Administrative Templates UI during configuration.
- Use the official policy documentation as source of truth:
   - https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca

### Steps

1. In Intune Admin Center, go to Devices -> Configuration -> Profiles.
2. Create an Imported Administrative Templates profile for Windows.
3. Import `secure-contacts.admx` and matching `secure-contacts.adml`.
4. Configure Secure Contacts settings in the profile UI.
5. Assign the profile to a DEVICE group (Machine-scope policy).
6. Validate on a test device in registry:
   - `HKLM\Software\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop`

## Method B: OMA-URI Custom Profile (manual or automated)

Use this when you want full Policy CSP control, scripting, or repeatable Graph-based rollout.

### Required files

- Common (both options):
   - `secure-contacts.admx`
- Option 1 (manual OMA-URI rows):
   - `secure-contacts.intune-oma-uri.md`
- Option 2 (automated Graph import):
   - `secure-contacts.intune-omauri-profile.json`
   - `import-secure-contacts-omauri.ps1`
- Conditional:
   - `secure-contacts.adml` (required when Intune prompts for matching locale metadata)

Important:
- `secure-contacts.intune-omauri-profile.json` is the blank template version; use `secure-contacts.intune-omauri-profile.example.json` when you want filled sample values.
- `secure-contacts.intune-oma-uri.md` is the blank template version; use `secure-contacts.intune-oma-uri.example.md` when you want filled sample values.
- Most Secure Contacts OMA-URI String values must contain a JSON array string, not a comma-separated plain text value.
- `SecContacts.Licenses` specifically uses JSON objects with `name` + `key`; most other JSON-backed settings use `name` + `value`.
- `SecContacts.AADCacheList` and `SecContacts.AzureBlobStorageList` are multi-string values and should contain one JSON object per line.
- Replace all sample values with production values before deployment.
- Use the official policy documentation as source of truth:
   - https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca

### Admin value-entry checklist

Use this checklist before assigning the profile to devices:

1. Method A: Imported Administrative Templates
   - Enter the production values directly in the Intune Administrative Templates UI.
   - No local JSON or markdown file is uploaded with final values for this method.

2. Method B, Option 1: Manual OMA-URI rows
   - Use `secure-contacts.intune-oma-uri.md` as the blank structure template.
   - Use `secure-contacts.intune-oma-uri.example.md` only as a reference for valid sample formats.
   - Paste your real production values into the Intune OMA-URI value fields.

3. Method B, Option 2: Automated Graph import
   - Fill your real production values into `secure-contacts.intune-omauri-profile.json`.
   - Use `secure-contacts.intune-omauri-profile.example.json` only as a reference for valid sample formats.
   - Then run `import-secure-contacts-omauri.ps1`.

4. For both Method B options
   - Keep the ADMX ingest setting in place.
   - Keep the values in JSON-array format where required.
   - Assign the finished profile to a DEVICE group.

### Steps

Option 1: Manual OMA-URI rows in Intune

1. Create a Windows Custom profile in Intune.
2. Add ADMX ingest row first:
   - `./Device/Vendor/MSFT/Policy/ConfigOperations/ADMXInstall/SecureContacts/Policy/SecureContactsAdmx`
3. Add Secure Contacts policy rows from `secure-contacts.intune-oma-uri.md`.
4. Assign to a DEVICE group.

Option 2: Automated Graph import

1. Install Graph module (once):

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

2. Run importer from this folder:

```powershell
.\import-secure-contacts-omauri.ps1
```

3. The script replaces the ADMX placeholder in JSON with the real ADMX content and creates the profile via Graph.
4. Assign profile `Secure Contacts - OMA URI (Device)` to a DEVICE group.
5. Validate on a test device in registry:
   - `HKLM\Software\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop`

## Choosing a setup path

- Choose Method A if your tenant supports Imported Administrative Templates and you want a native UI experience.
- Choose Method B if you need scripting/automation, explicit OMA-URI control, or a fallback path when Method A is unavailable.

## Result in Windows registry

Both methods ultimately apply the same machine policy values under:
- `HKLM\Software\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop`

## Common pitfalls

- Do not skip ADMX ingest; policy nodes depend on it.
- Use DEVICE assignment, not USER assignment (policies are Machine class).
- Keep ADML matching ADMX version/locale.
- The JSON file is a Graph payload template, not a direct portal upload file.
- Deploying sample/demo values to production tenants.

## Detailed references

- Official policy documentation: https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca
- `secure-contacts.intune-oma-uri.md`
- `README.intune-omauri-import.md`
- `import-secure-contacts-omauri.ps1`
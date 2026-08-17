# Secure Contacts Intune Configuration Manual (Windows)

This guide shows how to configure Secure Contacts for Windows in Microsoft Intune using two supported setup paths.

## Scope

This manual focuses on configuration and rollout, not policy design.

It applies to the Windows app configuration path only (ADMX/ADML and Windows Policy CSP OMA-URI).

You can configure the app using either of these methods:

- Method A: Import ADMX/ADML and configure settings through the Intune Administrative Templates UI.
- Method B: Use Custom OMA-URI settings (manual rows or the provided JSON + PowerShell importer).

## Prerequisites

- Microsoft Intune administrator permissions.
- Windows devices managed by Intune.
- Access to the Secure Contacts deployment files.
- Microsoft Graph PowerShell module (Method B Option 2 only).

> **App installation:** This guide covers app *configuration* only. To install Secure Contacts as an Intune Win32 app, use [`Install-SecureContacts.ps1`](Install-SecureContacts.ps1) as the install script and [`Test-SecureContactsInstalled.ps1`](Test-SecureContactsInstalled.ps1) as the detection rule. See [`SCA-Intune-Win32-Deploy-Manual-Win.md`](SCA-Intune-Win32-Deploy-Manual-Win.md) for the full deployment walkthrough.

## Choosing a setup path

- Choose **Method A** if your tenant supports Imported Administrative Templates and you want a native Intune configuration experience.
- Choose **Method B** if you need automation, scripting, direct OMA-URI control, or a fallback when Administrative Templates are unavailable.

## Assignment Recommendation

Secure Contacts policies are machine-scope policies that write values to:

`HKLM\Software\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop`

For this reason:

- Device assignment or device-group assignment is recommended.
- User-group assignment is supported by Intune.
- When assigned to users, policy application typically occurs after the targeted user signs in and the device completes policy synchronization.

## Method A: ADMX/ADML Imported Administrative Templates

Use this when you want a policy UI experience in Intune without managing OMA-URI rows directly.

### Required files

- `secure-contacts.admx`
- `secure-contacts.adml`

Important:

- `secure-contacts.admx` and `secure-contacts.adml` define the policy schema and policy UI labels.
- Enter your production values directly in the Intune Administrative Templates UI during configuration.
- Use the official policy documentation as the source of truth:
  - https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca

### Steps

1. In Intune Admin Center, go to Devices -> Configuration -> Profiles.
2. Create an Imported Administrative Templates profile for Windows.
3. Import `secure-contacts.admx` and the matching `secure-contacts.adml`.
4. Configure Secure Contacts settings in the profile UI.
5. Assign the profile according to the Assignment Recommendation section above.
6. Validate on a test device in the registry:
   - `HKLM\Software\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop`

## Method B: OMA-URI Custom Profile (manual or automated)

Use this when you want full Policy CSP control, scripting, or repeatable Graph-based rollout.

### Required files

#### Common (both options)

- `secure-contacts.admx`

#### Option 1: Manual OMA-URI rows

- `secure-contacts.intune-oma-uri.md`

#### Option 2: Automated Graph import

- `secure-contacts.intune-omauri-profile.json`
- `import-secure-contacts-omauri.ps1`

#### Additional file

- `secure-contacts.adml`

Notes:

- `secure-contacts.adml` is required for Administrative Template import.
- `secure-contacts.adml` may also be requested during ADMX ingestion workflows in Intune.

### Important

- `secure-contacts.intune-omauri-profile.json` is the blank template version.
- `secure-contacts.intune-omauri-profile.ready.json` is the convenience version with the current ADMX XML already embedded.
- Use `secure-contacts.intune-omauri-profile.example.json` when you want filled sample values.
- `secure-contacts.intune-oma-uri.md` is the blank template version. Use `secure-contacts.intune-oma-uri.example.md` when you want filled sample values.
- Most Secure Contacts OMA-URI String values must contain a JSON array string, not a comma-separated plain text value.
- `SecContacts.Licenses` specifically uses JSON objects with `name` and `key`.
- Most other JSON-backed settings use `name` and `value`.
- `SecContacts.AADCacheList` and `SecContacts.AzureBlobStorageList` are multi-string values and should contain one JSON object per line.
- Replace all sample values with production values before deployment.
- Use the official policy documentation as the source of truth:
  - https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca

### Admin value-entry checklist

Use this checklist before assigning the profile.

#### Method A: Imported Administrative Templates

- Enter the production values directly in the Intune Administrative Templates UI.
- No local JSON or markdown file is uploaded with final values for this method.

#### Method B, Option 1: Manual OMA-URI rows

- Use `secure-contacts.intune-oma-uri.md` as the blank structure template.
- Use `secure-contacts.intune-oma-uri.example.md` only as a reference for valid sample formats.
- Paste your real production values into the Intune OMA-URI value fields.
- If exported JSON examples show sequences like `\"`, that is expected: the payload is encoding JSON text inside XML inside an outer JSON string.

#### Method B, Option 2: Automated Graph import

- Fill your real production values into `secure-contacts.intune-omauri-profile.json`.
- Or start from `secure-contacts.intune-omauri-profile.ready.json` if you want the ADMXInstall payload already included.
- Use `secure-contacts.intune-omauri-profile.example.json` only as a reference for valid sample formats.
- Then run `import-secure-contacts-omauri.ps1`.

#### For both Method B options

- Keep the ADMX ingest setting in place.
- Keep values in JSON-array format where required.
- Prefer device or device-group assignment.

### Steps

#### Option 1: Manual OMA-URI rows in Intune

1. Create a Windows Custom profile in Intune.
2. Add the ADMX ingest row first:
   - `./Device/Vendor/MSFT/Policy/ConfigOperations/ADMXInstall/SecureContacts/Policy/SecureContactsAdmx`
3. Add the Secure Contacts policy rows from `secure-contacts.intune-oma-uri.md`.
4. Assign the profile according to the Assignment Recommendation section.

#### Option 2: Automated Graph import

1. Install the Microsoft Graph module (once):

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

2. Run the importer from this folder:

```powershell
.\import-secure-contacts-omauri.ps1
```

3. The script replaces the ADMX placeholder in the JSON file with the actual ADMX content and creates the profile via Microsoft Graph.
4. Assign profile `Secure Contacts - OMA URI (Device)` according to the Assignment Recommendation section.
5. Validate on a test device in the registry:
   - `HKLM\Software\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop`

## Expected result

After successful deployment:

- Secure Contacts policies exist under `HKLM\Software\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop`.
- The application automatically reads the managed configuration.
- No end-user configuration is required.
- Both deployment methods can produce the same effective policy configuration on the device when configured with the same values.

## Common pitfalls

- Do not skip ADMX ingest; policy nodes depend on it.
- Device assignment is recommended for this machine-scope policy.
- User-group assignment is supported but depends on user sign-in and policy synchronization.
- Keep ADML and ADMX versions/locales aligned.
- The JSON file is a Microsoft Graph payload template, not a direct Intune portal upload file.
- Deploying sample or demonstration values into production tenants.
- Using plain text values where a JSON array is required.

## Detailed references

- Official policy documentation: https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca
- `secure-contacts.intune-oma-uri.md`
- `import-secure-contacts-omauri.ps1`
- `README.intune-omauri-import.md`
- `Install-SecureContacts.ps1` — Win32 app install/update script
- `Test-SecureContactsInstalled.ps1` — Win32 app detection script
- `Test-SecureContactsUpToDate.ps1` — Win32 app up-to-date detection script
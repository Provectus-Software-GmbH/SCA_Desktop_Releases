# Secure Contacts Intune Configuration Manual (macOS)

This guide shows how to configure Secure Contacts for macOS with Microsoft Intune.

> **Related:** Deploy the signed application package first using [README.Intune-Deploy-MacOS.md](README.Intune-Deploy-MacOS.md).

## Scope

This is a managed-configuration manual, not an application deployment or schema design document.

Important:

- For Intune on macOS, there is one primary method (plist-based custom profile).
- A second path is included as optional for non-Intune MDM platforms.

## Prerequisites

- Microsoft Intune administrator permissions.
- Managed macOS devices.
- Access to the Secure Contacts deployment files.

## Platform scope

- Platform: macOS
- App bundle ID: `de.provectus.SecureContactsDesktop`
- Managed device-level target file:
  - `/Library/Managed Preferences/de.provectus.SecureContactsDesktop.plist`

## Deployment recommendation

- Use Method A for Microsoft Intune deployments.
- Use Method B only for Jamf, Kandji, or other non-Intune MDM platforms.

## Method A (Primary): Intune macOS custom profile with plist

Use this for normal Intune rollout.

### Required files

- `plist/de.provectus.SecureContactsDesktop.plist`

Important:

- `plist/de.provectus.SecureContactsDesktop.plist` is the blank production template.
- `plist/de.provectus.SecureContactsDesktop.plist.demo` is the reference example with sample values.
- Use the official policy documentation as source of truth:
  - https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca

### Admin value-entry checklist

Use this checklist before assigning the profile to devices.

#### Intune macOS preference file method

- Use `plist/de.provectus.SecureContactsDesktop.plist` as the blank production template.
- Use `plist/de.provectus.SecureContactsDesktop.plist.demo` only as a reference for valid sample formats.
- Enter your production values in `plist/de.provectus.SecureContactsDesktop.plist`.
- Upload or paste the completed content into Intune.

#### Optional non-Intune MDM method

- Use `plist/secure-contacts-manifest.json` as the schema reference.
- Build the vendor-specific payload in your MDM system with your real production values.

#### For both methods

- Keep unused optional keys empty.
- Keep JSON values valid and compact.
- Validate on a test device before broad rollout.

### Steps

1. In Intune Admin Center, go to Devices -> Configuration -> Profiles.
2. Create a macOS custom/app configuration profile.
3. Upload or paste values from `plist/de.provectus.SecureContactsDesktop.plist`.
4. Assign to a device group.
5. Validate on a test device first.

### Preference file format and key/value rules (Important)

For Intune macOS **Preference file** profiles, this file is intentionally a **fragment**.

- Keep only `<key>...</key>` and value nodes (for example `<string>`, `<array>`, `<false/>`).
- Do not wrap content in `<plist>`, `<dict>`, or XML root tags for this Intune template type.
- Each `SecContacts.*` key maps to one managed preference value in Intune.
- For this app, many values are JSON serialized into string values.
- Use this repository file as a structure template only. Replace placeholders with production values.

Current value expectations in this template:

All keys below are optional and can be left empty by default.

| Key | plist type | Format when used |
|---|---|---|
| `SecContacts.Defaults` | `<string>` | JSON array of objects: `[ { "name": "...", "value": "..." } ]` |
| `SecContacts.Licenses` | `<string>` | JSON array of objects: `[ { "name": "...", "key": "..." } ]` |
| `SecContacts.AADGroups` | `<string>` | JSON array of objects: `[ { "name": "...", "value": "..." } ]` |
| `SecContacts.AADCache` | `<string>` | JSON array of objects: `[ { "name": "...", "value": "..." } ]` |
| `SecContacts.ServiceUrls` | `<string>` | JSON array of objects: `[ { "name": "...", "value": "..." } ]` |
| `SecContacts.AzureBlobStorage` | `<string>` | JSON array of objects: `[ { "name": "...", "value": "..." } ]` |
| `SecContacts.SharedMailboxContacts` | `<string>` | JSON array of objects: `[ { "name": "...", "value": "..." } ]` |
| `SecContacts.CustomDatasourceNames` | `<string>` | JSON array of objects: `[ { "defaultid": "...", "customid": "...", "customname": "..." } ]` |

Tip:

- Keep JSON values compact and valid.
- If you don't use a key, keep it empty in the template instead of adding demo payloads.

### Verification

Run on the macOS device:

```bash
defaults read /Library/Managed\ Preferences/de.provectus.SecureContactsDesktop.plist
```

Note:

- `defaults read <bundle-id>` reads user domain settings.
- For MDM-applied policy, validate the managed preferences file path above.

## Method B (Optional): Non-Intune MDM using manifest schema

Use this only for Jamf, Kandji, or other MDM systems.

### Required files

- `plist/secure-contacts-manifest.json`

### Steps

1. Use `plist/secure-contacts-manifest.json` as the property schema.
2. Build the vendor-specific payload in your MDM system.
3. Map each `SecContacts.*` property to the target payload format.
4. Deploy to managed macOS devices.
5. Verify using the same command and file path as Method A.

## Supported configuration properties

- `SecContacts.Defaults`
- `SecContacts.Licenses`
- `SecContacts.AADGroups`
- `SecContacts.AADCache`
- `SecContacts.ServiceUrls`
- `SecContacts.AzureBlobStorage`
- `SecContacts.SharedMailboxContacts`
- `SecContacts.CustomDatasourceNames`

## Expected result

After successful deployment:

- Managed preferences are written to:
  - `/Library/Managed Preferences/de.provectus.SecureContactsDesktop.plist`
- Secure Contacts automatically reads the managed configuration.
- No end-user configuration is required.
- Intune and non-Intune MDM deployments can result in the same effective configuration being available to the application when configured with the same values.

## Common pitfalls

- Treating macOS like a Windows ADMX or OMA-URI policy workflow.
- Validating only user defaults instead of managed preferences.
- Assigning configuration to the wrong scope or device group.
- Mixing old and new key formats across environments.
- Deploying demo or template values to production tenants.
- Uploading a complete XML plist document where an Intune Preference File profile expects only the key/value fragment.

## References

- Official policy documentation: https://docs.secure-contacts.com/documentation/app-configuration-policy-name-values-for-sca
- `plist/de.provectus.SecureContactsDesktop.plist`
- `plist/secure-contacts-manifest.json`

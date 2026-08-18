# Secure Contacts ADMX -> Intune OMA-URI Mapping

This document provides OMA-URI entries for Microsoft Intune custom profiles.

## 1) Ingest the ADMX (required first)

Create one custom setting in Intune:

- Name: Secure Contacts ADMX Ingest
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/ConfigOperations/ADMXInstall/SecureContacts/Policy/SecureContactsAdmx
- Data type:
  - String (XML file)
- Value:
  - Paste the full contents of ..\ADMX\secure-contacts.admx

Notes:
- Upload the matching ADML file in Intune when prompted (locale-specific).
- The policy area used below is SecureContacts.

## 2) Policy OMA-URI entries

All policies are Device-scope and use String data type.

Category path resolved from ADMX:
- SecureContactsCategory -> SecContactsCategory

URI base:
- ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/

### Pol_Defaults
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_Defaults
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_Defaults" value="[{\"name\":\"aad_initvalue\",\"value\":\"true\"}]"/>
```

### Pol_DefaultsExtension
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_DefaultsExtension
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_DefaultsExtension" value="[{\"name\":\"searchalldatasources_initvalue\",\"value\":\"false\"}]"/>
```

### Pol_Licenses
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_Licenses
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_Licenses" value="[{\"name\":\"tenant-or-license-name\",\"key\":\"encrypted-license-key\"}]"/>
```

### Pol_AADGroups
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_AADGroups
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_AADGroups" value="[{\"name\":\"group-id-or-name\",\"value\":\"display-value\"}]"/>
```

### Pol_AADCache
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_AADCache
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_AADCache" value="[{\"name\":\"cache1\",\"value\":\"encryptedPayload\"}]"/>
```

### Pol_AADCacheList
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_AADCacheList
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_AADCacheList" value="{\"name\":\"cache1\",\"value\":\"encryptedPayload\"}"/>
```

Notes:
- `Pol_AADCacheList` maps to `SecContacts.AADCacheList` (multi-string registry value).
- For multiple entries, provide one JSON object per line in the policy UI.

### Pol_ServiceUrls
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_ServiceUrls
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_ServiceUrls" value="[{\"name\":\"baseUrl\",\"value\":\"https://api.example.com\"}]"/>
```

### Pol_AzureBlobStorage
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_AzureBlobStorage
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_AzureBlobStorage" value="[{\"name\":\"blob1\",\"value\":\"encryptedConnection\"}]"/>
```

### Pol_AzureBlobStorageList
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_AzureBlobStorageList
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_AzureBlobStorageList" value="{\"name\":\"blob1\",\"value\":\"encryptedConnection\"}"/>
```

Notes:
- `Pol_AzureBlobStorageList` maps to `SecContacts.AzureBlobStorageList` (multi-string registry value).
- For multiple entries, provide one JSON object per line in the policy UI.

### Pol_SharedMailboxContacts
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_SharedMailboxContacts
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_SharedMailboxContacts" value="[{\"name\":\"shared-mailbox\",\"value\":\"mailbox1@contoso.com\"}]"/>
```

### Pol_CustomDatasourceNames
- OMA-URI:
  - ./Device/Vendor/MSFT/Policy/Config/SecureContacts~Policy~SecureContactsCategory~SecContactsCategory/Pol_CustomDatasourceNames
- Data type:
  - String
- Value (enable with sample):

```xml
<enabled/><data id="Txt_CustomDatasourceNames" value="[{\"defaultid\":\"ABS1\",\"customid\":\"HUB\",\"customname\":\"HubSpot\"}]"/>
```

Notes:
- Most String policies above expect a JSON array serialized into the value field.
- `Pol_Licenses` uses objects with `name` + `key`.
- `Pol_AADCacheList` and `Pol_AzureBlobStorageList` are multi-string policies and take one JSON object per line.

## 3) Disable or clear a policy

To disable a policy via OMA-URI, use:

```xml
<disabled/>
```

To keep it enabled but provide an empty text value, use:

```xml
<enabled/><data id="Txt_..." value=""/>
```

## 4) Validation tips

- Assign policy to a test device first, because ADMX class is Machine.
- Verify under registry path:
  - HKLM\\Software\\Policies\\ProvectusSoftwareGmbH\\SecureContactsDesktop
- Expected value names:
  - SecContacts.Defaults
  - SecContacts.DefaultsExtension
  - SecContacts.Licenses
  - SecContacts.AADGroups
  - SecContacts.AADCache
  - SecContacts.AADCacheList
  - SecContacts.ServiceUrls
  - SecContacts.AzureBlobStorage
  - SecContacts.AzureBlobStorageList
  - SecContacts.SharedMailboxContacts
  - SecContacts.CustomDatasourceNames

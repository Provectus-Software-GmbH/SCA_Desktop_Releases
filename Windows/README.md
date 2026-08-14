# Secure Contacts — Windows Deployment Files

Windows Intune configuration files for Secure Contacts App (SCA). Supports ADMX/ADML imported templates and OMA-URI custom profiles (manual or PowerShell-automated via Graph).

**Start here:** [SCA-Intune-Config-Manual-Win.md](SCA-Intune-Config-Manual-Win.md)

## Files in this folder

| File | Role |
|---|---|
| [SCA-Intune-Config-Manual-Win.md](SCA-Intune-Config-Manual-Win.md) | Full Intune configuration guide (Method A: ADMX, Method B: OMA-URI) |
| [secure-contacts.admx](secure-contacts.admx) | ADMX policy schema — required for both Intune methods |
| [secure-contacts.adml](secure-contacts.adml) | Matching ADML locale labels for the ADMX |
| [secure-contacts.intune-oma-uri.md](secure-contacts.intune-oma-uri.md) | Blank OMA-URI row template for manual Intune entry |
| [secure-contacts.intune-oma-uri.example.md](secure-contacts.intune-oma-uri.example.md) | Filled OMA-URI reference showing valid sample values |
| [secure-contacts.intune-omauri-profile.json](secure-contacts.intune-omauri-profile.json) | Blank Graph API payload for the PowerShell importer |
| [secure-contacts.intune-omauri-profile.example.json](secure-contacts.intune-omauri-profile.example.json) | Filled Graph payload reference showing valid sample values |
| [import-secure-contacts-omauri.ps1](import-secure-contacts-omauri.ps1) | PowerShell script — creates the Intune profile via Microsoft Graph |
| [README.intune-omauri-import.md](README.intune-omauri-import.md) | Quick-start guide for the PowerShell importer |

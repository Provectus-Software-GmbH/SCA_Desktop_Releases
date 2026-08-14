# Secure Contacts — macOS Deployment Files

Secure Contacts App (SCA) is an enterprise contact management solution that lets organizations securely manage, synchronize, and distribute business contacts across managed devices.

This folder contains the files IT administrators need to configure and manage SCA on macOS devices. The primary method uses Intune plist-based custom profiles; a second path covers non-Intune MDM platforms such as Jamf and Kandji.

**Start here:** [SCA-Intune-Config-Manual-Mac.md](SCA-Intune-Config-Manual-Mac.md)

## Files in this folder

| File | Role |
|---|---|
| [SCA-Intune-Config-Manual-Mac.md](SCA-Intune-Config-Manual-Mac.md) | Full Intune configuration guide (plist method + non-Intune MDM) |
| [de.provectus.SecureContactsDesktop.plist](de.provectus.SecureContactsDesktop.plist) | Blank plist config template for production use |
| [de.provectus.SecureContactsDesktop.plist.demo](de.provectus.SecureContactsDesktop.plist.demo) | Demo plist with sample values (reference only) |
| [secure-contacts-manifest.json](secure-contacts-manifest.json) | Manifest schema reference for non-Intune MDM platforms |

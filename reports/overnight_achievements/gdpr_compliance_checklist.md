# GDPR Compliance Checklist (Starter) — 2.2.0 Draft

This is a **starter** checklist to drive the next sprint. It complements the in-app 2.5.* gates already implemented.

## Data inventory (map what exists today)
- [ ] **Documents**: encrypted blobs (`.vgenc`) + encrypted metadata (`.vgmeta`) under app private storage
- [ ] **Consents**: stored locally in `SharedPreferences` (`vaultguard_prefs`) + `consent_log.txt` (local audit log)
- [ ] **Keys**: Android Keystore aliases prefixed with SecureStorage alias base
- [ ] **Logs**: ensure logs do not contain sensitive data (OCR text, biometrics, keys)

## Lawful basis & consent
- [x] Separate consent gates:
  - [x] 2.5.1 legal disclaimer
  - [x] 2.5.2 privacy policy acceptance
  - [x] 2.5.3 biometric consent + revoke
- [ ] Add versioning for privacy policy text (store accepted version + require re-accept on changes)

## Data subject rights
- [x] **Right to erasure**: 2.5.4 delete all data + keys
- [x] **Right to portability**: 2.5.5 export ZIP (metadata + consent history + encrypted backup)
- [ ] Add in-app “Contact / DPO” and compliance contact details before launch

## Security (Art. 32)
- [x] Encryption at rest via Android Keystore + AES-GCM
- [ ] Threat model doc + logging redaction policy
- [ ] Regular key rotation policy surfaced to user/admin if required

## Retention / minimization
- [ ] 2.5.6 define retention policy (what is stored, for how long, and why)
- [ ] Add “delete after N days” option (optional) and document defaults

## Background capture prohibition
- [ ] 2.5.7 enforce foreground-only biometric flows (audit services/background workers)

## Cloud backup rules
- [ ] 2.5.8 explicit opt-in; ensure only documents are included; never biometric templates


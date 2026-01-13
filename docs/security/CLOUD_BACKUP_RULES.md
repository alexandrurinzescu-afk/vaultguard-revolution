# Cloud Backup Rules (GDPR 2.5.8)

## Goal
Ensure there is **no implicit cloud backup** of sensitive local state (consents, logs, secure storage) while still supporting **user-controlled data portability**.

## Policy (current Android implementation)
- **Automatic OS backup is disabled** via `android:allowBackup="false"` in `app/src/main/AndroidManifest.xml`.
- **Opt-in portability** is provided via the in-app export flow (**2.5.5**):
  - Export is explicitly user-initiated.
  - Export package includes **metadata + consent history + encrypted backup** (no plaintext).
  - Export excludes biometric templates (none are stored by design).

## Rationale
- OS-level backups are not reliably user-configurable at runtime and may include files/preferences that are sensitive.
- A manual export flow provides transparency and explicit user intent, aligning with minimization and consent expectations.

## Future (iOS / cross-platform)
- Apply the same rule: **no iCloud backup for biometric templates**.
- If any cloud backup feature is added, it must be:
  - **Explicit opt-in**
  - **Encrypted**
  - **Documents only** (never biometric templates)
  - Clearly documented in privacy disclosures.


## VaultGuard Security Guide (Phase 2 target)

### Current state (repo today)
- `KeystoreManager` exists (implemented in `com.vaultguard.security.keystore.KeystoreManager`).
- Enrollment flow is **TODO**.
- Reporting exists (HTML) and must avoid sensitive logs.

### Principles
- **Encrypt biometric data at rest** using Android Keystore + AES-GCM.
- **Never log sensitive payloads** (templates, raw frames, keys).
- **Least privilege**: only required permissions; review `AndroidManifest.xml`.

### Recommended implementation plan (practical)
- **Keystore keys**
  - Generate an AES key in Android Keystore.
  - Use AES-GCM (12-byte IV) with authenticated encryption.
- **Storage**
  - Store ciphertext + IV + metadata; keep IV per-record.
  - Consider EncryptedSharedPreferences for small secrets; Room/SQLite for records.
- **Logging**
  - Create a redaction helper to prevent logging secrets.

### Checklist
- [x] Implement `KeystoreManager` (generate key, encrypt, decrypt)
- [ ] Implement enrollment pipeline (capture → verify → store encrypted template)
- [ ] Add threat model doc and update retention policy for any persisted logs
- [ ] Add basic tests for crypto primitives (unit tests)


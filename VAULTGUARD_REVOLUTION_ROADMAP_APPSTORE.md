# VAULTGUARD REVOLUTION - ROADMAP (APP STORE COMPLIANT)

**Data creare (original):** 2026-01-09 15:14:39  
**Versiune:** 1.1 (App Store compliant)  
**Repo root:** `C:\Users\pc\VaultGuardRevolution`  
**Status curent:** In desfasurare

---

## LEGAL DISCLAIMER (MANDATORY)
**This app provides biometric authentication for accessing user's personal documents, not official identity verification.**  
- Aplicatia este destinata **securizarii accesului la documente personale** in cadrul aplicatiei.
- Aplicatia **NU** ofera verificare oficiala de identitate, **NU** este recunoscuta de guverne si **NU** furnizeaza capabilitati KYC/AML.
- Orice referinta la "verificare guvernamentala" / "identitate digitala" / "KYC" este **in afara scopului** si trebuie eliminata/refactorizata.

---

## SISTEM DE URMARIRE
- [x] = COMPLETAT
- [ ] = IN ASTEPTARE
- [!] = SCOS DIN SCOP / NEPERMIS (App Store)

---

# CAPITOL 1: FAZA 1 - FUNDATIE & SETUP

## 1.1 PROIECT INITIALIZARE
- [x] 1.1.1 Creare structura proiect Android
- [x] 1.1.2 Configurare Git repository
- [x] 1.1.3 Setup Android Studio workspace (confirmare manuala)
- [x] 1.1.4 Configurare Gradle wrapper
- [x] 1.1.5 Initial commit cu structura de baza (optional: curatare + commit coerent)

## 1.2 DOCUMENTATIE & PLANIFICARE
- [x] 1.2.1 Creare document roadmap (acest fisier)
- [x] 1.2.2 Documentatie arhitectura
- [ ] 1.2.3 Specificatii tehnice (hardware targets + moduri scanare)
- [ ] 1.2.4 Plan de testare (unit + instrumented)
- [ ] 1.2.5 Checklist resurse necesare (device lab + SDK-uri)

## 1.3 CONFIGURATIE DEZVOLTARE
- [x] 1.3.1 Setup toolchain (JDK, Android SDK) - build OK pe acest PC
- [x] 1.3.2 Configurare dependinte de baza
- [ ] 1.3.3 Structura package-uri (curatare/standardizare)
- [ ] 1.3.4 Configurare code style & linting (ktlint/detekt optional)
- [!] 1.3.5 Debugging tools care pot expune date sensibile (log redaction obligatoriu inainte)

---

# CAPITOL 2: FAZA 2 - CORE SECURITY ENGINE (APP ACCESS CONTROL)

## 2.1 KEYSTORE MANAGER (ENCRYPTION PRIMITIVES)
- [x] 2.1.1 Creare/validare KeystoreManager.kt
- [x] 2.1.2 Implementare Android KeyStore
- [x] 2.1.3 Generare chei AES-GCM
- [x] 2.1.4 Operatii criptografice de baza (encrypt/decrypt + metadata)
- [ ] 2.1.5 Unit tests pentru Keystore

## 2.2 BIOMETRIC AUTHENTICATION FOR APP ACCESS
- [x] 2.2.1 Integrare BiometricPrompt API (pentru gate de securitate UI)
- [ ] 2.2.2 Facial recognition (ML Kit) - DOAR pentru imbunatatire UX in-app (NU verificare oficiala)
- [ ] 2.2.3 Stocare template-uri biometric (criptat) - DOAR cu consimtamant explicit, local-only
- [ ] 2.2.4 Verificare 1:1 biometrica (match) - DOAR pentru acces in-app, fara pretentii KYC/AML
- [ ] 2.2.5 Fallback mecanic (PIN/pattern/device credential) pentru acces in-app

## 2.3 SECURE STORAGE (PERSONAL DOCUMENT VAULT)
- [ ] 2.3.1 Encrypted SharedPreferences (secrets mici)
- [x] 2.3.2 Secure file encryption (blob-uri mari)
- [ ] 2.3.3 Credential management (in-app)
- [x] 2.3.4 Key rotation mechanism
- [x] 2.3.5 Secure deletion (one-click delete all user data)

## 2.4 SECURITY AUDIT (IN-APP ONLY)
- [ ] 2.4.1 Vulnerability assessment (internal)
- [ ] 2.4.2 Penetration testing setup (internal)
- [ ] 2.4.3 Security logging (redaction; no sensitive payloads)
- [ ] 2.4.4 Compliance checklist (App Store privacy + GDPR delete flow)
- [ ] 2.4.5 Security documentation (threat model, consumer scope)

## 2.5 GDPR & PRIVACY COMPLIANCE (APP STORE + BIOMETRIE)
- [ ] 2.5.1 Legal disclaimer (no official identity verification; no government recognition; no KYC/AML)
- [ ] 2.5.2 Privacy policy in-app (accept/decline gateway) + link web
- [ ] 2.5.3 Explicit biometric consent (separate consent for iris/palm vein processing; revoke anytime)
- [ ] 2.5.4 Data deletion flow (one-click delete all user data + keys) + confirmation UX
- [ ] 2.5.5 Data export (user-controlled export of documents/metadata; redacted logs)
- [ ] 2.5.6 Data minimization & retention (store only what is needed; define retention policy; no hidden tracking)
- [ ] 2.5.7 No background biometric capture (foreground-only; user-initiated prompts)
- [ ] 2.5.8 iCloud/Cloud backup rules (documents only; NOT biometric templates; encrypted; opt-in)

---

# CAPITOL 3: FAZA 3 - HARDWARE INTEGRATION (OPTIONAL, CONSUMER-SAFE)

## 3.1 HUIFAN X05 / SDK ANALYSIS
- [ ] 3.1.1 Obtine fisiere SDK (HuiFan/X05) + documentatie
- [ ] 3.1.2 Analiza structura SDK (JAR/AAR + SO + API)
- [ ] 3.1.3 Documentatie tehnica review
- [ ] 3.1.4 Compatibilitate verificare (ABI, minSdk, permisiuni)
- [ ] 3.1.5 Integration plan creation (flows in-app, foreground only)

## 3.2 SCANNER CONNECTION
- [ ] 3.2.1 USB-C/Bluetooth communication (daca e cazul)
- [ ] 3.2.2 Device discovery protocol
- [ ] 3.2.3 Command/response implementation
- [ ] 3.2.4 Error handling & recovery
- [ ] 3.2.5 Connection stability testing

## 3.3 IRIS RECOGNITION ENGINE (FOREGROUND ONLY)
- [ ] 3.3.1 Iris image capture (foreground, user-initiated)
- [ ] 3.3.2 Quality assessment algorithms
- [ ] 3.3.3 Template extraction (local-only; encrypted)
- [ ] 3.3.4 Matching engine integration (for in-app access only)
- [ ] 3.3.5 Performance optimization

## 3.4 UNIVERSAL FALLBACK SYSTEM (IN-APP UX)
- [ ] 3.4.1 Camera phone detection (quality helper)
- [ ] 3.4.2 Adaptive quality adjustment
- [ ] 3.4.3 Seamless mode switching (within app)
- [ ] 3.4.4 User preference management
- [ ] 3.4.5 Quality comparison metrics

---

# CAPITOL 4: FAZA 4 - CONSUMER FEATURES (NO GOVERNMENT / NO KYC)

## 4.1 MODULAR ARCHITECTURE (IN-APP)
- [ ] 4.1.1 Plugin system design (internal modules)
- [ ] 4.1.2 Module interface definition
- [ ] 4.1.3 Dependency injection setup
- [ ] 4.1.4 Dynamic module loading (optional; keep App Store safe)
- [ ] 4.1.5 Module version management

## 4.2 CONSUMER MODULES DEVELOPMENT
- [ ] 4.2.1 Document Vault Pro (secure storage + advanced OCR; no identity claims)
- [ ] 4.2.2 Family/Trusted Sharing (secure sharing between users; app-level only)
- [!] 4.2.3 Government Verification Module (REMOVED - not App Store / consumer scope)
- [ ] 4.2.4 Personal Security Check Module (device integrity + privacy controls; in-app only)
- [ ] 4.2.5 Education / Security Guides Module (user education, setup help)

## 4.3 CLOUD INTEGRATION (REFocused)
- [ ] 4.3.1 Encrypted iCloud Backup (documents only; NOT biometric templates)
- [ ] 4.3.2 Multi-device support (consumer Apple ID; encrypted)
- [ ] 4.3.3 Conflict resolution
- [ ] 4.3.4 Offline capability (core must work offline)
- [ ] 4.3.5 Data privacy compliance (explicit consent; export/delete)

## 4.4 ADMIN DASHBOARD
- [!] 4.4.1 Web admin interface (out of consumer App Store scope)
- [!] 4.4.2 User management (enterprise scope)
- [!] 4.4.3 Analytics & reporting (enterprise scope)
- [ ] 4.4.4 Audit logs (in-app user-facing export; redacted)
- [ ] 4.4.5 System configuration (in-app settings only)

---

# CAPITOL 5: FAZA 5 - APP STORE LAUNCH & MONETIZATION

## 5.1 APP STORE PREPARATION
- [ ] 5.1.1 App Store listing (consumer)
- [ ] 5.1.2 App Store Optimization
- [ ] 5.1.3 Screenshots & promotional materials (no identity/KYC claims)
- [ ] 5.1.4 Privacy policy & terms (in-app access)
- [ ] 5.1.5 Beta testing program (TestFlight)

## 5.2 PARTNERSHIPS & INTEGRATION (CONSUMER-SAFE)
- [ ] 5.2.1 Cloud backup partners (iCloud only; avoid KYC/AML language)
- [ ] 5.2.2 Consumer security vendors (optional; no enterprise enforcement)
- [!] 5.2.3 Government pilot programs (REMOVED)
- [ ] 5.2.4 OEM partnership exploration (optional; consumer safe)
- [ ] 5.2.5 Export/import formats (PDF/ZIP encrypted; user-controlled)

## 5.3 ENTERPRISE FEATURES
- [!] 5.3.1 SSO integration (enterprise scope)
- [!] 5.3.2 Active Directory sync (enterprise scope)
- [!] 5.3.3 Custom branding (enterprise scope)
- [!] 5.3.4 Advanced reporting (enterprise scope)
- [!] 5.3.5 SLA agreements (enterprise scope)

## 5.4 GLOBAL EXPANSION
- [ ] 5.4.1 Localization & i18n
- [ ] 5.4.2 Regional compliance (privacy laws; no gov identity verification)
- [ ] 5.4.3 Market-specific features (consumer security)
- [ ] 5.4.4 Partnership networks (consumer)
- [ ] 5.4.5 Support center setup

---

## PROGRES GLOBAL (manual)
- Completat: 17 / 95
- In progres: 2.1.5 (tests) + 1.2.3 (specs)
- Urmatorul subpunct recomandat: **2.1.5** (Unit tests pentru Keystore)

---

## SISTEM DE BACKUP DUPA FIECARE SUBPUNCT (protocol)

1. Dupa fiecare subpunct marcat [x]:
   - Ruleaza scriptul `scripts/backup_after_subpoint.ps1`
   - Scriptul face:
     - update la checkbox-ul din roadmap
     - commit + tag (daca Git e disponibil si exista modificari)
     - backup zip in `backups/`

2. Checkpoint la fiecare 5 subpuncte (manual, deocamdata):
   - Full project backup .zip
   - Documentatie sincronizata

# VAULTGUARD REVOLUTION - ROADMAP STRUCTURAT

**Data creare:** 2026-01-09 15:14:39  
**Versiune:** 1.0  
**Repo root:** `C:\Users\pc\AndroidStudioProjects\VaultGuard`  
**Status curent:** In desfasurare

---

## SISTEM DE URMARIRE
- [x] = COMPLETAT
- [ ] = IN ASTEPTARE
- [!] = BLOCAT (manual, daca e cazul)

---

# CAPITOL 1: FAZA 1 - FUNDATIE & SETUP

## 1.1 PROIECT INITIALIZARE
- [x] 1.1.1 Creare structura proiect Android
- [x] 1.1.2 Configurare Git repository
- [ ] 1.1.3 Setup Android Studio workspace (confirmare manuala)
- [x] 1.1.4 Configurare Gradle wrapper
- [ ] 1.1.5 Initial commit cu structura de baza (optional: curatare + commit coerent)

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
- [ ] 1.3.5 Setup debugging tools (profiling + logs redaction)

---

# CAPITOL 2: FAZA 2 - CORE SECURITY ENGINE

## 2.1 KEYSTORE MANAGER
- [ ] 2.1.1 Creare/validare KeystoreManager.kt
- [ ] 2.1.2 Implementare Android KeyStore
- [ ] 2.1.3 Generare chei AES-GCM
- [ ] 2.1.4 Operatii criptografice de baza (encrypt/decrypt + metadata)
- [ ] 2.1.5 Unit tests pentru Keystore

## 2.2 BIOMETRIC AUTHENTICATION
- [ ] 2.2.1 Integrare BiometricPrompt API (pentru gate de securitate UI)
- [ ] 2.2.2 Facial recognition de baza (ML Kit) - stabilizare pipeline
- [ ] 2.2.3 Stocare template-uri biometric (criptat)
- [ ] 2.2.4 Verificare 1:1 biometrica (match)
- [ ] 2.2.5 Fallback mecanic (PIN/pattern)

## 2.3 SECURE STORAGE
- [ ] 2.3.1 Encrypted SharedPreferences (secrets mici)
- [ ] 2.3.2 Secure file encryption (blob-uri mari)
- [ ] 2.3.3 Credential management
- [ ] 2.3.4 Key rotation mechanism
- [ ] 2.3.5 Secure deletion

## 2.4 SECURITY AUDIT
- [ ] 2.4.1 Vulnerability assessment
- [ ] 2.4.2 Penetration testing setup
- [ ] 2.4.3 Security logging (redaction)
- [ ] 2.4.4 Compliance checklist
- [ ] 2.4.5 Security documentation (threat model)

---

# CAPITOL 3: FAZA 3 - DUAL BIOMETRIC HARDWARE INTEGRATION (IRIS + PALMVEIN)

## 3.1 IRIS - DEVICE & SDK FOUNDATION
- [ ] 3.1.1 Obtine fisiere SDK iris (EyeCool/HuiFan/X05) + documentatie
- [ ] 3.1.2 Validare compatibilitate (ABI, minSdk, permisiuni, transport)
- [ ] 3.1.3 Standardizare packaging (app/libs + app/src/main/jniLibs)
- [ ] 3.1.4 Definire contract API (capture/quality/template) pentru iris
- [ ] 3.1.5 Implementare pipeline captare iris (stub -> SDK real)

## 3.2 IRIS - TEMPLATE & MATCHING
- [ ] 3.2.1 Integrare extractie template (SDK)
- [ ] 3.2.2 Quality scoring (focus/exposure/occlusion) + feedback UI
- [ ] 3.2.3 Liveness / anti-spoof baseline (daca SDK suporta; altfel heuristici)
- [ ] 3.2.4 1:1 matching integration + praguri initiale
- [ ] 3.2.5 Enrollment flow (iris) end-to-end + metrici/calibrare

## 3.3 PALMVEIN - DEVICE & SDK FOUNDATION
- [ ] 3.3.1 Obtine fisiere SDK palmvein + documentatie (BLOCAT pana la fisiere)
- [ ] 3.3.2 Validare compatibilitate (ABI, minSdk, permisiuni, transport)
- [ ] 3.3.3 Definire contract API (capture/quality/template) pentru palmvein
- [ ] 3.3.4 Implementare pipeline captare palmvein (stub -> SDK real)
- [ ] 3.3.5 Standardizare management erori (disconnect/timeouts/retry)

## 3.4 PALMVEIN - TEMPLATE & MATCHING
- [ ] 3.4.1 Integrare extractie template (SDK)
- [ ] 3.4.2 Quality scoring (ROI/contrast/noise) + feedback UI
- [ ] 3.4.3 Liveness / presentation attack baseline (daca e disponibil)
- [ ] 3.4.4 1:1 matching integration + praguri initiale
- [ ] 3.4.5 Enrollment flow (palmvein) end-to-end + metrici/calibrare

## 3.5 DUAL BIOMETRIC ORCHESTRATION (IRIS + PALMVEIN)
- [ ] 3.5.1 Unified session state machine (capture -> quality -> template -> match)
- [ ] 3.5.2 Strategie de fuziune (AND/OR, score-level fusion, risk-based)
- [ ] 3.5.3 Politici de fallback + retry (ordine moduri, rate limits, lockouts)
- [ ] 3.5.4 Storage mapping securizat (2 modalitati + metadata) via Keystore
- [ ] 3.5.5 Audit events + privacy: fara template-uri/bytes in loguri

## 3.6 UNIVERSAL FALLBACK & RECOVERY
- [ ] 3.6.1 Mod fallback (camera phone) - limitari + criterii acceptare
- [ ] 3.6.2 Adaptive guidance UI (mesaje calitate, iluminare, pozitionare)
- [ ] 3.6.3 Recovery & stability tests (timeouts, reconnect, memory pressure)
- [ ] 3.6.4 Re-enrollment + template rotation plan (per user/device)
- [ ] 3.6.5 Performance envelope (FPS, latency, battery) pe device matrix

---

# CAPITOL 4: FAZA 4 - UNIVERSAL PLATFORM

## 4.1 MODULAR ARCHITECTURE
- [ ] 4.1.1 Plugin system design
- [ ] 4.1.2 Module interface definition
- [ ] 4.1.3 Dependency injection setup
- [ ] 4.1.4 Dynamic module loading
- [ ] 4.1.5 Module version management

## 4.2 MARKET MODULES DEVELOPMENT
- [ ] 4.2.1 Financial Security Module
- [ ] 4.2.2 Enterprise Access Module
- [ ] 4.2.3 Government Verification Module
- [ ] 4.2.4 Healthcare Authentication Module
- [ ] 4.2.5 Education Platform Module

## 4.3 CLOUD INTEGRATION
- [ ] 4.3.1 Sync service design
- [ ] 4.3.2 Multi-device support
- [ ] 4.3.3 Conflict resolution
- [ ] 4.3.4 Offline capability
- [ ] 4.3.5 Data privacy compliance

## 4.4 ADMIN DASHBOARD
- [ ] 4.4.1 Web admin interface
- [ ] 4.4.2 User management
- [ ] 4.4.3 Analytics & reporting
- [ ] 4.4.4 Audit logs
- [ ] 4.4.5 System configuration

---

# CAPITOL 5: FAZA 5 - LAUNCH & SCALING

## 5.1 APP STORE PREPARATION
- [ ] 5.1.1 Google Play Store listing
- [ ] 5.1.2 App Store Optimization
- [ ] 5.1.3 Screenshots & promotional materials
- [ ] 5.1.4 Privacy policy & terms
- [ ] 5.1.5 Beta testing program

## 5.2 PARTNERSHIPS & INTEGRATION
- [ ] 5.2.1 Banking/fintech partnerships
- [ ] 5.2.2 Enterprise security vendors
- [ ] 5.2.3 Government pilot programs
- [ ] 5.2.4 OEM bundling opportunities
- [ ] 5.2.5 API partner program

## 5.3 ENTERPRISE FEATURES
- [ ] 5.3.1 SSO integration
- [ ] 5.3.2 Active Directory sync
- [ ] 5.3.3 Custom branding
- [ ] 5.3.4 Advanced reporting
- [ ] 5.3.5 SLA agreements

## 5.4 GLOBAL EXPANSION
- [ ] 5.4.1 Localization & i18n
- [ ] 5.4.2 Regional compliance
- [ ] 5.4.3 Market-specific features
- [ ] 5.4.4 Partnership networks
- [ ] 5.4.5 Support center setup

---

# CAPITOL 6: FAZA 6 - ENTERPRISE FEATURES

## 6.1 IDENTITY & ACCESS MANAGEMENT (IAM)
- [ ] 6.1.1 SSO strategy (OIDC/SAML) + provider matrix
- [ ] 6.1.2 SCIM provisioning baseline (users/groups)
- [ ] 6.1.3 RBAC model (roles/scopes/policies) + mapping in UI/admin
- [ ] 6.1.4 Device attestation plan (Play Integrity / SafetyNet replacement)
- [ ] 6.1.5 Audit logs export format (sanitized, enterprise-friendly)

## 6.2 COMPLIANCE & GOVERNANCE
- [ ] 6.2.1 Threat model update pentru dual biometrics (iris + palmvein)
- [ ] 6.2.2 Data retention + deletion policy (templates + metadata)
- [ ] 6.2.3 Consent + privacy notice flows (per modality)
- [ ] 6.2.4 Incident response runbook (keys compromise / device loss)
- [ ] 6.2.5 Security review checklist per release (pre-flight gate)

## 6.3 OPERATIONS & DEPLOYMENT (ENTERPRISE)
- [ ] 6.3.1 CI hardening (signing, secrets, reproducible builds)
- [ ] 6.3.2 Telemetry/crash strategy (opt-in, redacted, no biometric payload)
- [ ] 6.3.3 Feature flags pentru rollout (iris-only -> dual -> enterprise)
- [ ] 6.3.4 Enterprise configuration profiles (policy packs)
- [ ] 6.3.5 Support diagnostics bundle (sanitized) + export

---

## PROGRES GLOBAL (manual)
- Completat: (auto-calc in script viitor)
- In progres: (manual)
- Total subpuncte (target): 110 (85 + 25 noi: dual biometrics + enterprise)
- Urmatorul subpunct recomandat: **1.1.5** (curatare + commit coerent) sau **2.1.1** (KeystoreManager)

---

## SISTEM DE BACKUP DUPA FIECARE SUBPUNCT (protocol)

1. Dupa fiecare subpunct marcat [x]:
   - Ruleaza scriptul `scripts/backup_after_subpoint.ps1`
   - Scriptul face:
     - update la checkbox-ul din acest roadmap
     - commit + tag (daca Git e disponibil si exista modificari)
     - backup zip in `backups/`

2. Checkpoint la fiecare 5 subpuncte (manual, deocamdata):
   - Full project backup .zip
   - Documentatie sincronizata


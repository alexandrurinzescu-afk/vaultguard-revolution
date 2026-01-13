## VaultGuard Architecture (current repo state)

### Scope
This document reflects what exists today in `AndroidStudioProjects/VaultGuard` (Kotlin + Compose + CameraX + ML Kit), plus planned work noted as TODO.

### High-level modules
- **App UI (Compose + some XML)**: `app/src/main/java/com/example/vaultguard/*`
- **Camera (CameraX)**: `com.example.vaultguard.revolution.*`
- **AI (ML Kit Face Detection)**: `com.example.vaultguard.revolution.ai.FaceDetectorProcessor`
- **Hardware integration (HuiFan / EyeCool assets)**:
  - Code stub: `com.example.vaultguard.revolution.hardware.HuiFanManagerRevolution`
  - Native libs: `app/src/main/jniLibs/**`
  - JARs: `app/libs/**`
- **Security (implemented + planned)**:
  - `com.vaultguard.security.keystore.KeystoreManager` (implemented)
  - `com.vaultguard.security.SecureStorage` (implemented: encrypted files + backup + rotation)
  - `com.vaultguard.security.biometric.*` (implemented: BiometricPrompt gate + session window)
  - `com.example.vaultguard.enrollment.EnrollmentManager` (currently TODO)

### Product architecture (strategic) — 3-tier in ONE app
We ship a single app binary that can operate in **3 modes** controlled by entitlements ("feature flags"):
- **Angel Lite**: demo/onboarding (free). No real hardware biometric capture. Focus: value demo + upgrade CTA.
- **Angel**: real app mode unlocked after paid gate + identity verification. Enables real biometric enrollment/auth.
- **Revolution**: premium features unlocked via website purchase (server flips entitlement) to avoid store fees.

#### Entitlements (client model)
- `isLiteMode`: demo mode (default for new installs until activated)
- `isAngelActivated`: full biometric features enabled (after purchase + identity verification)
- `isRevolutionActivated`: premium/enterprise features enabled (after website upgrade)

#### Where this lives in code (Android)
- Tier model/prefs: `com.example.vaultguard.tier.*`
- Feature gating helper: `isFeatureEnabled(feature)`
- UI uses feature flags to hide/show screens and protect sensitive operations.

#### Backend contract (planned)
At login / token refresh, backend returns entitlements:
`{ isLiteMode, isAngelActivated, isRevolutionActivated, issuedAt, signature }`
Client treats entitlements as authoritative (no local "unlock" outside debug builds).

### Data flow (typical scan / capture loop)
1. **UI** launches camera preview.
2. **CameraX ImageAnalysis** produces frames.
3. **FaceDetectorProcessor** runs ML Kit detection asynchronously.
4. **UI overlays** render bounding boxes / targeting overlay.
5. **Hardware managers** (planned) capture biometric data and return templates.
6. **KeystoreManager** encrypts templates for storage (Android Keystore AES-GCM).

### Key design choices (recommended)
- Prefer **one UI paradigm** (Compose) to reduce duplication with XML layouts.
- Treat **biometric templates** as sensitive and keep them encrypted at rest.
- Keep logging **metadata-only** (no templates/bytes) to avoid leaks in Logcat.

### Near-term refactor targets
- Consolidate camera preview into a single implementation (avoid duplication between `CameraPreview.kt` and `RevolutionCamera.kt` preview paths).
- Replace simulation logic in `HuiFanManagerRevolution` with real SDK calls behind an interface.
- Unify legacy `com.example.vaultguard.security.KeystoreManager` usage behind `com.vaultguard.security.keystore.KeystoreManager` (single source of truth).


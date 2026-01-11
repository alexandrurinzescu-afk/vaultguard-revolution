## X05 integration (network module) - VaultGuard

### What exists now
This repo contains EyeCool JAR/SO assets (iris/uvc). There is no dedicated "X05 fingerprint SDK" JAR in `app/libs` yet.

So Phase 2 starts with a **network communication module** that can work with X05 devices that expose:
- TCP on `10010`
- HTTP on `9000`
- Endpoints:
  - `GET /MIPS/config`
  - `POST /MIPS/upload`

### Code locations
- Models:
  - `app/src/main/java/com/example/vaultguard/device/model/DeviceStatus.kt`
  - `app/src/main/java/com/example/vaultguard/device/model/EncryptedBlob.kt`
  - `app/src/main/java/com/example/vaultguard/device/model/FingerprintTemplate.kt`
- X05 module:
  - `app/src/main/java/com/example/vaultguard/device/x05/X05DeviceManager.kt`
  - `app/src/main/java/com/example/vaultguard/device/x05/X05TcpClient.kt`
  - `app/src/main/java/com/example/vaultguard/device/x05/X05HttpClient.kt`
  - `app/src/main/java/com/example/vaultguard/device/x05/X05Endpoints.kt`
- Security:
  - `app/src/main/java/com/vaultguard/security/keystore/KeystoreManager.kt` (AES-GCM via Android Keystore, auth-gated)

### Quick connectivity probe (PC side)
Run on Windows (PowerShell):

```powershell
cd "C:\Users\pc\AndroidStudioProjects\VaultGuard"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\x05_probe.ps1"
```

### Next implementation steps (to reach real bi-directional comms)
- Confirm the actual X05 TCP protocol framing (length-prefix, newline, protobuf, etc.)
- Implement message framing + command set in `X05TcpClient`
- Add retry policy + metrics (timeouts, error rates)
- Add a UI screen to show device status and run a "test transaction"


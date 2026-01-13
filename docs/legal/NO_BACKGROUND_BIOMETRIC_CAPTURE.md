# No Background Biometric Capture (2.5.7)

Policy:
- VaultGuard Revolution must not capture or request biometrics in the background.
- Biometric prompts must be **foreground-only** and **user-initiated**.

Implementation:
- All biometric prompt entry points require an Activity and enforce `lifecycle >= STARTED`.
- If an attempt is made to trigger biometric authentication from a background state, it is blocked.


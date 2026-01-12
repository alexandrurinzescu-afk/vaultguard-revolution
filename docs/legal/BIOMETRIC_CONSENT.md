# Biometric Consent (Draft)

This document describes the **explicit biometric consent** required before enabling biometric features in VaultGuard Revolution.

## What this consent covers
- Device biometrics via Android **BiometricPrompt** (fingerprint/face, depending on device capabilities).
- Optional future hardware modules (e.g., iris/palm) if enabled by the user.

## What this consent does NOT mean
- It does **not** provide government-recognized identity verification.
- It does **not** create legal identity ownership.

## “First-to-Claim” concept (app-level)
VaultGuard Revolution may support an internal “claim” concept to reduce impersonation **within the app**. This is a product/security concept, not a legal system.

## Revocation
Users must be able to revoke biometric consent at any time. Upon revocation:
- biometric features are disabled until consent is granted again
- the app should avoid processing biometric templates/signals beyond what the OS requires


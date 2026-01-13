# “First-to-Claim” Registry — MVP Design (Draft)

## Goal
Provide an **app-level** identity claim concept that helps prevent impersonation **within VaultGuard**.

> This is **not** government identity verification and has no legal authority.

## MVP scope (recommended)
- Local-only prototype first (no backend)
- Claim record ties to a local device + local biometric consent state
- Later: optional server-backed registry with device attestation

## Data model (MVP)
`Claim`
- `claimId` (UUID)
- `userLabel` (string; the name/handle being claimed)
- `createdAt` (ISO timestamp)
- `deviceIdHash` (hash; generated locally)
- `biometricConsentVersion` + `biometricConsentAt`
- `status`: ACTIVE | REVOKED

## Flows
1. **Claim**
   - Pre-req: 2.5.3 biometric consent accepted
   - User picks handle → stored as ACTIVE claim
2. **Verify**
   - Check if handle is already ACTIVE
   - If yes and belongs to current device: OK
   - If yes and not this device: block / warn
3. **Revoke**
   - Revoking biometric consent revokes claim (recommended MVP rule)

## Security notes
- Never store biometric templates in the registry (store only metadata + consent state).
- If server-backed later:
  - require device attestation
  - rate limit claim attempts
  - add admin override / dispute workflow

## Next implementation step
- Create a local `ClaimStore` (SharedPreferences or encrypted file) + simple UI page.


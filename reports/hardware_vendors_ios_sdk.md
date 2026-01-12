# iOS Biometric Hardware Vendors (iOS SDK) — Research Report (Draft)

> **IMPORTANT LIMITATION (environment):** automated web search is currently returning unusable/non-listing results, so **Alibaba product links could not be reliably collected from here**.  
> This report therefore provides a **shortlist of likely vendors + a validation checklist + outreach template**, and is intended to be **confirmed manually** (Alibaba / vendor sites) before purchase.

## Success criteria (what we must confirm)
- **Must have**: native **iOS SDK** delivered as `.framework` / `.xcframework`
- **Must have**: Swift/Objective‑C docs + **sample Xcode project**
- **Must have**: clear hardware connectivity story (USB‑C / BLE / Lightning / MFi)
- **Should have**: prototype price \< **$800**
- **Avoid**: “Android SDK only”, “Windows SDK only”, “SDK available soon”, “cloud-only API without local capture”

## Candidate vendor shortlist (needs confirmation)

| Vendor / Product family | Modality | iOS SDK claim (status) | Connectivity | Notes / Risks | Next action |
|---|---|---:|---|---|---|
| **IriTech** (IriShield / iris modules) | Iris | **Unconfirmed** | USB / OEM modules | Known iris OEM; iOS packaging varies by model/integration partner | Ask for `.xcframework` + sample Xcode |
| **Iris ID** (iris cameras) | Iris | **Unconfirmed** | USB / OEM | Often enterprise-focused; may have partner-only SDK | Request iOS SDK + licensing terms |
| **EyeLock** (iris) | Iris | **Unconfirmed** | OEM | Enterprise; may not target mobile directly | Ask for iOS integration path |
| **Fujitsu PalmSecure** | Palm vein | **Unconfirmed** | USB (typical) | Many deployments are Windows-focused; iOS may be limited | Ask if any iOS kit exists |
| **Hitachi / finger vein** (various OEM channels) | Finger vein | **Unconfirmed** | USB | Often SDK is Windows; mobile support uncertain | Confirm mobile SDK availability |
| **Suprema** (fingerprint) | Fingerprint | **Unconfirmed** | USB / BLE | Some products have mobile SDKs (Android/iOS) depending on line | Ask for iOS SDK + example app |
| **HID Global** (readers) | Fingerprint / access | **Unconfirmed** | BLE/NFC/USB | HID has mobile integrations for access control; biometric capture support varies | Ask specifically for capture + matching SDK |

> If you want the “Alibaba-first” version: manually search Alibaba with keywords:
> - `iris scanner iOS SDK`, `palm vein iOS SDK`, `finger vein iPhone SDK`, `biometric device iOS framework`, `xcframework biometric`
> and filter: “Ready to Ship”, “Trade Assurance”, “MOQ 1”, “Response within 24h”.

## Technical validation checklist (ask vendors)
1. Provide **SDK download** and exact package format (`.xcframework` preferred).
2. Confirm **supported iOS versions** and device requirements.
3. Confirm **connectivity** method (USB‑C, BLE, Lightning/MFi) and required accessories.
4. Provide a **sample Xcode project** + API reference.
5. Confirm whether matching is **on-device**, **on-hardware**, or **cloud**.
6. Confirm licensing: offline use, redistribution, fees, per-device activation.
7. Confirm export controls / compliance constraints (biometrics sometimes restricted).

## Outreach template (send to top 3)
Subject: iOS SDK request for biometric integration (prototype order)

Hello,
We are building an iPhone app that requires biometric integration.

Do you provide a native iOS SDK for your [PRODUCT NAME]?
We need:
1) iOS framework (.framework/.xcframework)
2) Swift/Objective‑C documentation
3) Sample Xcode project
4) Unit price for 1 prototype + shipping ETA

If available, please share the SDK download link and licensing terms.
Thank you.

## Recommendation (next steps)
1. Do a **manual Alibaba sweep** and replace the shortlist above with **real product links**.
2. Contact top 3 sellers and require **SDK proof** (download + sample project).
3. Only then place MOQ=1 order for the best candidate.


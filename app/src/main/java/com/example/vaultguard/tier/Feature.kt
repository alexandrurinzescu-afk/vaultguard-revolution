package com.example.vaultguard.tier

/**
 * App capabilities that are gated by entitlements.
 *
 * Keep this vendor-agnostic: features describe outcomes, not SDK names.
 */
enum class Feature {
    DEMO_ONBOARDING,
    ID_VERIFICATION,
    REAL_BIOMETRIC_ENROLLMENT,
    REAL_BIOMETRIC_AUTH,
    PREMIUM_REVOLUTION_FEATURES,
}


package com.example.vaultguard.tier

/**
 * Centralized feature flag evaluation.
 *
 * NOTE: For now this is entitlement-only. Later we can add:
 * - remote config
 * - app version gating
 * - device capability gating
 */
object FeatureGate {
    fun isFeatureEnabled(entitlements: UserEntitlements, feature: Feature): Boolean {
        return when (feature) {
            Feature.DEMO_ONBOARDING -> true
            Feature.ID_VERIFICATION -> entitlements.isAngelActivated || entitlements.isRevolutionActivated
            Feature.REAL_BIOMETRIC_ENROLLMENT -> entitlements.isAngelActivated || entitlements.isRevolutionActivated
            Feature.REAL_BIOMETRIC_AUTH -> entitlements.isAngelActivated || entitlements.isRevolutionActivated
            Feature.PREMIUM_REVOLUTION_FEATURES -> entitlements.isRevolutionActivated
        }
    }
}


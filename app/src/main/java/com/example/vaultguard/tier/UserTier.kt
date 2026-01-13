package com.example.vaultguard.tier

/**
 * Product tier (3-tier strategy):
 * - LITE: demo/onboarding mode
 * - ANGEL: activated (paid gate + identity verification)
 * - REVOLUTION: premium entitlements enabled (website upgrade)
 */
enum class UserTier {
    LITE,
    ANGEL,
    REVOLUTION,
}


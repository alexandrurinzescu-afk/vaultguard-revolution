package com.example.vaultguard.tier

import android.content.Context

/**
 * Entitlements repository.
 *
 * In production, this will be backed by auth + signed entitlements.
 * In Sprint 0.1.2, we use a local backend stub.
 */
class EntitlementsRepository(
    private val api: EntitlementsApiClient = EntitlementsApiClient(),
) {
    suspend fun refreshEntitlements(context: Context): Result<UserTier> {
        val userId = InstallId.getOrCreate(context)
        return runCatching {
            val dto = api.getEntitlements(userId)
            val tier = UserTier.valueOf(dto.tier)
            TierPrefs.setUserTier(context, tier)
            tier
        }
    }

    suspend fun mockPurchaseAngel(context: Context): Result<UserTier> {
        val userId = InstallId.getOrCreate(context)
        return runCatching {
            val dto = api.mockPurchase(userId, tier = UserTier.ANGEL.name)
            val tier = UserTier.valueOf(dto.tier)
            TierPrefs.setUserTier(context, tier)
            tier
        }
    }

    suspend fun mockPurchaseRevolution(context: Context): Result<UserTier> {
        val userId = InstallId.getOrCreate(context)
        return runCatching {
            val dto = api.mockPurchase(userId, tier = UserTier.REVOLUTION.name)
            val tier = UserTier.valueOf(dto.tier)
            TierPrefs.setUserTier(context, tier)
            tier
        }
    }
}


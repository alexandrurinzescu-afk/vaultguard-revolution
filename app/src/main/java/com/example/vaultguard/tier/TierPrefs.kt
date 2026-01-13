package com.example.vaultguard.tier

import android.content.Context

/**
 * Local tier storage.
 *
 * IMPORTANT:
 * - In production this should be driven by backend entitlements, not client toggles.
 * - This is a scaffold so UI can be developed now without hardware/vendor decisions.
 */
object TierPrefs {
    private const val PREFS_NAME = "vaultguard_tier_prefs"
    private const val KEY_USER_TIER = "user_tier"

    fun getUserTier(context: Context): UserTier {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_USER_TIER, UserTier.LITE.name)
            ?: UserTier.LITE.name

        return runCatching { UserTier.valueOf(raw) }.getOrDefault(UserTier.LITE)
    }

    fun setUserTier(context: Context, tier: UserTier) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_USER_TIER, tier.name)
            .apply()
    }
}


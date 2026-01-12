package com.example.vaultguard.gdpr

import android.content.Context

/**
 * Minimal GDPR/privacy gate preferences.
 *
 * NOTE: This is a simple local flag. Later we can evolve it into a proper consent registry with versions.
 */
object GdprPrefs {
    private const val PREFS_NAME = "vaultguard_prefs"

    private const val KEY_LEGAL_DISCLAIMER_ACCEPTED = "legal_disclaimer_accepted"

    fun isLegalDisclaimerAccepted(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_LEGAL_DISCLAIMER_ACCEPTED, false)
    }

    fun setLegalDisclaimerAccepted(context: Context, accepted: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_LEGAL_DISCLAIMER_ACCEPTED, accepted)
            .apply()
    }
}


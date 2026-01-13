package com.example.vaultguard.tier

import android.content.Context
import java.util.UUID

/**
 * Local installation identifier (dev scaffold).
 *
 * Backend entitlements need a stable user identifier. Until a real auth system exists,
 * we use an install-scoped UUID stored in SharedPreferences.
 */
object InstallId {
    private const val PREFS_NAME = "vaultguard_install"
    private const val KEY_INSTALL_ID = "install_id"

    fun getOrCreate(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_INSTALL_ID, null)
        if (!existing.isNullOrBlank()) return existing

        val id = UUID.randomUUID().toString()
        prefs.edit().putString(KEY_INSTALL_ID, id).apply()
        return id
    }
}


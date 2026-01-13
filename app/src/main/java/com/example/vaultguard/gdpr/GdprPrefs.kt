package com.example.vaultguard.gdpr

import android.content.Context
import java.time.Instant
import java.time.format.DateTimeFormatter

/**
 * Minimal GDPR/privacy gate preferences.
 *
 * NOTE: This is a simple local flag. Later we can evolve it into a proper consent registry with versions.
 */
object GdprPrefs {
    private const val PREFS_NAME = "vaultguard_prefs"

    private const val KEY_LEGAL_DISCLAIMER_ACCEPTED = "legal_disclaimer_accepted"
    private const val KEY_PRIVACY_POLICY_ACCEPTED = "privacy_policy_accepted"
    private const val KEY_BIOMETRIC_CONSENT_ACCEPTED = "biometric_consent_accepted"
    private const val KEY_BIOMETRIC_CONSENT_TIMESTAMP_ISO = "biometric_consent_ts_iso"
    private const val KEY_BIOMETRIC_CONSENT_VERSION = "biometric_consent_version"
    private const val KEY_DATA_RETENTION_DAYS = "data_retention_days"

    private const val BIOMETRIC_CONSENT_VERSION = 1

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

    fun isPrivacyPolicyAccepted(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_PRIVACY_POLICY_ACCEPTED, false)
    }

    fun setPrivacyPolicyAccepted(context: Context, accepted: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_PRIVACY_POLICY_ACCEPTED, accepted)
            .apply()
    }

    fun isBiometricConsentAccepted(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_BIOMETRIC_CONSENT_ACCEPTED, false)
    }

    fun biometricConsentTimestampIso(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_BIOMETRIC_CONSENT_TIMESTAMP_ISO, null)
    }

    fun biometricConsentVersion(context: Context): Int {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_BIOMETRIC_CONSENT_VERSION, 0)
    }

    fun setBiometricConsentAccepted(context: Context, accepted: Boolean) {
        val nowIso = DateTimeFormatter.ISO_INSTANT.format(Instant.now())
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_BIOMETRIC_CONSENT_ACCEPTED, accepted)
            .putInt(KEY_BIOMETRIC_CONSENT_VERSION, BIOMETRIC_CONSENT_VERSION)
            .putString(KEY_BIOMETRIC_CONSENT_TIMESTAMP_ISO, nowIso)
            .apply()

        appendConsentLog(context, if (accepted) "BIOMETRIC_CONSENT_ACCEPTED" else "BIOMETRIC_CONSENT_REVOKED", nowIso)
    }

    private fun appendConsentLog(context: Context, event: String, isoTs: String) {
        // Minimal local logging for audit/debug. No network, no analytics SDK.
        runCatching {
            val line = "$isoTs|$event|v=$BIOMETRIC_CONSENT_VERSION\n"
            context.openFileOutput("consent_log.txt", Context.MODE_APPEND).use { it.write(line.toByteArray()) }
        }
    }

    fun wipeConsentAndPolicyPrefs(context: Context) {
        runCatching {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().apply()
        }
        runCatching { context.deleteFile("consent_log.txt") }
    }

    /**
     * Data retention window in days for local encrypted storage files.
     * 0 means "forever" (no deletion).
     */
    fun dataRetentionDays(context: Context): Int {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_DATA_RETENTION_DAYS, 365)
    }

    fun setDataRetentionDays(context: Context, days: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY_DATA_RETENTION_DAYS, days.coerceAtLeast(0))
            .apply()
    }
}


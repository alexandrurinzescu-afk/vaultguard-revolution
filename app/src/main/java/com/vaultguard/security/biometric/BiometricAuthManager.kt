package com.vaultguard.security.biometric

import android.content.Context
import android.content.SharedPreferences
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import com.vaultguard.security.SecureStorage
import com.vaultguard.security.biometric.ui.BiometricAuthResult
import com.vaultguard.security.biometric.ui.BiometricResultHandler
import java.util.concurrent.TimeUnit

/**
 * 2.1.2 Biometric Authentication UI gate for security operations.
 *
 * Note: Keystore keys are configured as user-auth-required.
 * This manager provides an explicit BiometricPrompt gate + a 30-second session window.
 */
class BiometricAuthManager(
    context: Context,
    private val keystore: KeystoreOps = AndroidKeystoreOps(context),
    private val promptFactory: (FragmentActivity) -> PromptClient = { BiometricPromptController(it) },
    private val sessionSeconds: Int = 30,
) {
    private val appContext = context.applicationContext
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun isSessionValid(nowMillis: Long = System.currentTimeMillis()): Boolean {
        val expiresAt = prefs.getLong(KEY_EXPIRES_AT_MS, 0L)
        return expiresAt > nowMillis
    }

    fun clearSession() {
        prefs.edit().remove(KEY_EXPIRES_AT_MS).apply()
    }

    private fun ensureForeground(activity: FragmentActivity, reason: String): BiometricAuthResult.Error? {
        // 2.5.7 Guardrail: BiometricPrompt must be shown only from a foreground/visible UI state.
        // If someone tries to trigger it from background, block immediately.
        val ok = activity.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
        return if (ok) {
            null
        } else {
            BiometricAccessLogger.append(
                context = appContext,
                event = "BLOCKED_BACKGROUND",
                reason = reason,
                details = "lifecycle=${activity.lifecycle.currentState}",
            )
            BiometricAuthResult.Error(-3, "Blocked: biometric prompt requires foreground UI.")
        }
    }

    fun authenticate(
        activity: FragmentActivity,
        reason: String = "Authenticate",
        handler: BiometricResultHandler,
    ) {
        BiometricAccessLogger.append(appContext, event = "ATTEMPT", reason = reason)
        ensureForeground(activity, reason)?.let { handler.onResult(it); return }

        // Rate limiting + exponential backoff gate.
        val now = System.currentTimeMillis()
        val lockoutUntil = prefs.getLong(KEY_LOCKOUT_UNTIL_MS, 0L)
        if (lockoutUntil > now) {
            val seconds = ((lockoutUntil - now) / 1000L).coerceAtLeast(1L)
            BiometricAccessLogger.append(appContext, event = "BLOCKED_RATE_LIMIT", reason = reason, details = "seconds=$seconds")
            handler.onResult(BiometricAuthResult.Error(-1, "Rate limited. Try again in ${seconds}s."))
            return
        }

        // Sliding window: max 5 attempts / minute.
        val windowStart = prefs.getLong(KEY_WINDOW_START_MS, 0L)
        val windowCount = prefs.getInt(KEY_WINDOW_COUNT, 0)
        val withinWindow = windowStart != 0L && now - windowStart <= TimeUnit.MINUTES.toMillis(1)
        val newWindowStart = if (withinWindow) windowStart else now
        val newCount = if (withinWindow) windowCount else 0
        if (newCount >= MAX_ATTEMPTS_PER_MINUTE) {
            val backoffMs = computeBackoffMs(prefs.getInt(KEY_CONSEC_FAILS, 0) + 1)
            prefs.edit()
                .putLong(KEY_LOCKOUT_UNTIL_MS, now + backoffMs)
                .putLong(KEY_WINDOW_START_MS, newWindowStart)
                .putInt(KEY_WINDOW_COUNT, newCount)
                .apply()
            BiometricAccessLogger.append(appContext, event = "BLOCKED_RATE_LIMIT", reason = reason, details = "backoffMs=$backoffMs")
            handler.onResult(BiometricAuthResult.Error(-1, "Too many attempts. Backing off for ${backoffMs / 1000L}s."))
            return
        }

        val controller = promptFactory(activity)
        controller.authenticate(
            title = "VaultGuard Authentication",
            subtitle = reason,
            description = "Biometric verification required to proceed.",
            requireConfirmation = true,
            allowDeviceCredentialFallback = true,
            handler = handlerBlock@{ result ->
                // Update attempt counters (count only actual prompt interactions).
                val currNow = System.currentTimeMillis()
                val started = prefs.getLong(KEY_WINDOW_START_MS, 0L).let {
                    if (it == 0L || currNow - it > TimeUnit.MINUTES.toMillis(1)) currNow else it
                }
                val count = if (started == currNow) 1 else (prefs.getInt(KEY_WINDOW_COUNT, 0) + 1)

                when (result) {
                    is BiometricAuthResult.Success -> {
                        val expiresAt = currNow + (sessionSeconds * 1000L)
                        prefs.edit()
                            .putLong(KEY_EXPIRES_AT_MS, expiresAt)
                            .putInt(KEY_CONSEC_FAILS, 0)
                            .putLong(KEY_LOCKOUT_UNTIL_MS, 0L)
                            .putLong(KEY_WINDOW_START_MS, started)
                            .putInt(KEY_WINDOW_COUNT, count)
                            .apply()
                        BiometricAccessLogger.append(appContext, event = "SUCCESS", reason = reason)
                    }

                    is BiometricAuthResult.Cancelled -> {
                        // Don't punish cancellation; just count the attempt in the window.
                        prefs.edit()
                            .putLong(KEY_WINDOW_START_MS, started)
                            .putInt(KEY_WINDOW_COUNT, count)
                            .apply()
                        BiometricAccessLogger.append(appContext, event = "CANCELLED", reason = reason)
                    }

                    is BiometricAuthResult.Failed,
                    is BiometricAuthResult.Error,
                    -> {
                        val fails = prefs.getInt(KEY_CONSEC_FAILS, 0) + 1
                        val backoffMs = computeBackoffMs(fails)

                        // Self-destruct after 10 failed attempts.
                        if (fails >= SELF_DESTRUCT_FAILS) {
                            runCatching { SecureStorage(appContext).wipeAllStoredData(deleteKeys = true) }
                            prefs.edit().clear().apply()
                            BiometricAccessLogger.append(appContext, event = "SELF_DESTRUCT_WIPE", reason = reason, details = "fails=$fails")
                            handler.onResult(BiometricAuthResult.Error(-2, "Vault wiped after $SELF_DESTRUCT_FAILS failed attempts."))
                            return@handlerBlock
                        }

                        prefs.edit()
                            .putInt(KEY_CONSEC_FAILS, fails)
                            .putLong(KEY_LOCKOUT_UNTIL_MS, currNow + backoffMs)
                            .putLong(KEY_WINDOW_START_MS, started)
                            .putInt(KEY_WINDOW_COUNT, count)
                            .apply()
                        BiometricAccessLogger.append(
                            appContext,
                            event = "FAILED",
                            reason = reason,
                            details = "fails=$fails backoffMs=$backoffMs",
                        )
                    }
                }

                handler.onResult(result)
            },
        )
    }

    fun generateKeyWithBiometricGate(
        activity: FragmentActivity,
        alias: String,
        handler: (result: BiometricAuthResult) -> Unit,
    ) {
        ensureForeground(activity, "Generate key")?.let { handler(it); return }
        if (isSessionValid()) {
            keystore.generateKey(alias)
            handler(BiometricAuthResult.Success)
            return
        }
        authenticate(activity, reason = "Generate encryption key") { auth ->
            if (auth is BiometricAuthResult.Success) {
                keystore.generateKey(alias)
            }
            handler(auth)
        }
    }

    fun deleteKeyWithBiometricGate(
        activity: FragmentActivity,
        alias: String,
        handler: (result: BiometricAuthResult) -> Unit,
    ) {
        ensureForeground(activity, "Delete key")?.let { handler(it); return }
        if (isSessionValid()) {
            keystore.deleteKey(alias)
            handler(BiometricAuthResult.Success)
            return
        }
        authenticate(activity, reason = "Delete encryption key") { auth ->
            if (auth is BiometricAuthResult.Success) {
                keystore.deleteKey(alias)
            }
            handler(auth)
        }
    }

    fun encryptWithBiometricGate(
        activity: FragmentActivity,
        plaintext: ByteArray,
        alias: String,
        handler: (result: BiometricAuthResult, encrypted: ByteArray?, iv: ByteArray?) -> Unit,
    ) {
        ensureForeground(activity, "Encrypt")?.let { handler(it, null, null); return }
        if (isSessionValid()) {
            val r = keystore.encrypt(plaintext, alias)
            handler(BiometricAuthResult.Success, r.encryptedData, r.iv)
            return
        }

        authenticate(activity, reason = "Encrypt data") { auth ->
            if (auth is BiometricAuthResult.Success) {
                val r = keystore.encrypt(plaintext, alias)
                handler(auth, r.encryptedData, r.iv)
            } else {
                handler(auth, null, null)
            }
        }
    }

    fun decryptWithBiometricGate(
        activity: FragmentActivity,
        encryptedData: ByteArray,
        iv: ByteArray,
        alias: String,
        handler: (result: BiometricAuthResult, plaintext: ByteArray?) -> Unit,
    ) {
        ensureForeground(activity, "Decrypt")?.let { handler(it, null); return }
        if (isSessionValid()) {
            val p = keystore.decrypt(encryptedData, iv, alias)
            handler(BiometricAuthResult.Success, p)
            return
        }

        authenticate(activity, reason = "Decrypt data") { auth ->
            if (auth is BiometricAuthResult.Success) {
                val p = keystore.decrypt(encryptedData, iv, alias)
                handler(auth, p)
            } else {
                handler(auth, null)
            }
        }
    }

    private companion object {
        private const val PREFS_NAME = "vaultguard_biometric_session"
        private const val KEY_EXPIRES_AT_MS = "expires_at_ms"

        // Maximum security settings
        private const val MAX_ATTEMPTS_PER_MINUTE = 5
        private const val SELF_DESTRUCT_FAILS = 10

        private const val KEY_WINDOW_START_MS = "window_start_ms"
        private const val KEY_WINDOW_COUNT = "window_count"
        private const val KEY_CONSEC_FAILS = "consecutive_failures"
        private const val KEY_LOCKOUT_UNTIL_MS = "lockout_until_ms"

        private fun computeBackoffMs(consecutiveFails: Int): Long {
            // Exponential backoff: 1s, 2s, 4s, 8s... capped at 60s.
            val exp = (1L shl (consecutiveFails.coerceIn(0, 6))) * 1000L
            return exp.coerceAtMost(60_000L)
        }
    }
}


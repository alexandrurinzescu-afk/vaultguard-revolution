package com.vaultguard.security.biometric

import android.content.Context
import java.time.Instant
import java.time.format.DateTimeFormatter

/**
 * 2.5.7 Biometric access transparency log (local-only).
 *
 * - No analytics, no network.
 * - Do not write sensitive data; only minimal event metadata.
 */
object BiometricAccessLogger {
    private const val FILE_NAME = "biometric_access_log.txt"

    fun append(context: Context, event: String, reason: String, details: String = "") {
        val ts = DateTimeFormatter.ISO_INSTANT.format(Instant.now())
        val safeReason = reason.replace("\n", " ").take(120)
        val safeDetails = details.replace("\n", " ").take(200)
        val line = "$ts|$event|reason=$safeReason|$safeDetails\n"
        runCatching {
            context.applicationContext.openFileOutput(FILE_NAME, Context.MODE_APPEND).use { out ->
                out.write(line.toByteArray())
            }
        }
    }

    fun clear(context: Context) {
        runCatching { context.applicationContext.deleteFile(FILE_NAME) }
    }
}


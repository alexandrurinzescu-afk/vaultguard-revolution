package com.example.vaultguard.gdpr

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.io.BufferedReader
import java.io.File
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit

/**
 * 2.5.6 Data minimization & retention (local-only).
 *
 * Implementation notes:
 * - We do NOT decrypt anything here (safe to run at app startup).
 * - We delete encrypted blobs (.vgenc) and their metadata (.vgmeta) based on file lastModified.
 */
object DataRetentionManager {
    // Keep in sync with SecureStorage's default directory name.
    private const val STORAGE_DIR = "vaultguard_secure_storage"
    private const val RETENTION_LOG_FILE = "retention_log.txt"
    private const val CONSENT_LOG_FILE = "consent_log.txt"
    private const val UNIQUE_WORK_NAME = "vaultguard_retention_cleanup"

    fun applyRetentionIfNeeded(context: Context, nowMillis: Long = System.currentTimeMillis()): Int {
        val days = GdprPrefs.dataRetentionDays(context)
        if (days <= 0) return 0 // forever

        val cutoff = nowMillis - TimeUnit.DAYS.toMillis(days.toLong())
        val dir = File(context.filesDir, STORAGE_DIR)
        if (!dir.exists() || !dir.isDirectory) return 0

        var deleted = 0
        val files = dir.listFiles()?.toList().orEmpty()

        // Delete both vgenc and vgmeta older than cutoff.
        for (f in files) {
            if (!f.isFile) continue
            val name = f.name
            val supported = name.endsWith(".vgenc") || name.endsWith(".vgmeta")
            if (!supported) continue
            if (f.lastModified() < cutoff) {
                if (runCatching { f.delete() }.getOrDefault(false)) {
                    deleted++
                    appendRetentionLog(context, "DELETED_FILE", "name=$name")
                }
            }
        }

        // Consent log minimization: keep only events within the retention window (best-effort).
        // This is safe because it is a local audit helper, not a legal record, and is user-controlled via retention setting.
        val trimmed = trimConsentLog(context, cutoffMillis = cutoff)
        if (trimmed > 0) {
            appendRetentionLog(context, "TRIMMED_CONSENT_LOG", "trimmedLines=$trimmed")
        }

        if (deleted > 0) {
            appendRetentionLog(context, "RETENTION_RUN", "deleted=$deleted days=$days")
        }
        return deleted
    }

    fun schedulePeriodicRetention(context: Context) {
        // We do NOT require network; we do prefer the device not be low on battery.
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
            .setRequiresBatteryNotLow(true)
            .build()

        val req = PeriodicWorkRequestBuilder<RetentionCleanupWorker>(1, TimeUnit.DAYS)
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
            UNIQUE_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            req,
        )
    }

    private fun trimConsentLog(context: Context, cutoffMillis: Long): Int {
        val f = File(context.filesDir, CONSENT_LOG_FILE)
        if (!f.exists() || !f.isFile) return 0

        val isoCutoff = DateTimeFormatter.ISO_INSTANT.format(Instant.ofEpochMilli(cutoffMillis))

        // Format: <iso>|<event>|v=<n>
        val kept = ArrayList<String>(128)
        var trimmed = 0

        runCatching {
            context.openFileInput(CONSENT_LOG_FILE).bufferedReader().use(BufferedReader::readLines).forEach { line ->
                val ts = line.substringBefore('|', missingDelimiterValue = "")
                // ISO-8601 strings are lexicographically sortable for same format.
                if (ts.isNotBlank() && ts >= isoCutoff) kept.add(line) else trimmed++
            }
        }.onFailure { return 0 }

        // Only rewrite if we trimmed anything.
        if (trimmed <= 0) return 0

        runCatching {
            context.openFileOutput(CONSENT_LOG_FILE, Context.MODE_PRIVATE).use { out ->
                kept.forEach { out.write((it.trimEnd() + "\n").toByteArray()) }
            }
        }.onFailure { return 0 }

        return trimmed
    }

    private fun appendRetentionLog(context: Context, event: String, details: String) {
        val ts = DateTimeFormatter.ISO_INSTANT.format(Instant.now())
        val line = "$ts|$event|$details\n"
        runCatching {
            context.openFileOutput(RETENTION_LOG_FILE, Context.MODE_APPEND).use { out ->
                out.write(line.toByteArray())
            }
        }
    }
}


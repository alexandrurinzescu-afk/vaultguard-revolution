package com.example.vaultguard.gdpr

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * 2.5.6 Data minimization & retention: periodic cleanup worker.
 *
 * Runs best-effort and never decrypts data.
 */
class RetentionCleanupWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return runCatching {
            DataRetentionManager.applyRetentionIfNeeded(applicationContext)
            Result.success()
        }.getOrElse {
            // Don't crash the scheduler; retry later.
            Result.retry()
        }
    }
}


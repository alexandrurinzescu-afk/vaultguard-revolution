package com.vaultguard.security.hardening

import android.content.Context
import android.os.Debug
import android.os.Build
import java.io.File

/**
 * Lightweight device integrity checks.
 *
 * NOTE:
 * - Root detection on Android is heuristic-based; no single check is perfect.
 * - This is intended as a hardening layer, not a formal attestation system.
 */
object DeviceIntegrity {
    enum class CompromiseReason {
        DEBUGGER_ATTACHED,
        ROOT_INDICATORS,
    }

    fun getCompromiseReasons(): Set<CompromiseReason> {
        val reasons = LinkedHashSet<CompromiseReason>()
        if (isDebuggerAttached()) reasons.add(CompromiseReason.DEBUGGER_ATTACHED)
        if (hasRootIndicators()) reasons.add(CompromiseReason.ROOT_INDICATORS)
        return reasons
    }

    fun isCompromised(): Boolean = getCompromiseReasons().isNotEmpty()

    private fun isDebuggerAttached(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }

    private fun hasRootIndicators(): Boolean {
        // Build tags can be a signal (not definitive).
        val tags = Build.TAGS
        if (tags != null && tags.contains("test-keys")) return true

        // Common su paths.
        val suPaths = listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/data/local/bin/su",
            "/data/local/xbin/su",
        )
        if (suPaths.any { File(it).exists() }) return true

        // Magisk indicators (heuristics).
        val magiskPaths = listOf(
            "/sbin/magisk",
            "/data/adb/magisk",
            "/data/adb/modules",
        )
        if (magiskPaths.any { File(it).exists() }) return true

        return false
    }
}


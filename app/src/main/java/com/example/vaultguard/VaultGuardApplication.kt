package com.example.vaultguard

import android.app.Application
import android.content.pm.ApplicationInfo
import android.os.Process
import com.vaultguard.security.SecureStorage
import com.vaultguard.security.hardening.DeviceIntegrity
import kotlin.system.exitProcess

/**
 * App-wide hardening entry point.
 *
 * Policy (as requested):
 * - If a debugger is attached or root indicators are detected, wipe the vault and terminate.
 *
 * NOTE: This is intentionally aggressive. If you want a "warn + read-only" mode instead,
 * we can adjust the policy.
 */
class VaultGuardApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val storage = SecureStorage(this)

        // Seamless key rotation (90 days) + re-encryption migration.
        runCatching { storage.rotateKeysIfNeeded() }

        val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (DeviceIntegrity.isCompromised()) {
            // Best-effort wipe (ignore exceptions).
            runCatching { storage.wipeAllStoredData(deleteKeys = true) }

            // For development builds, don't kill the process (otherwise debugging becomes impossible).
            // Release builds enforce "immediate shutdown".
            if (!isDebuggable) {
                Process.killProcess(Process.myPid())
                exitProcess(0)
            }
        }
    }
}


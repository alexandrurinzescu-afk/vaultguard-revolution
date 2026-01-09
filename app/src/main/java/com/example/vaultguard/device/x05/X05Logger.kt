package com.example.vaultguard.device.x05

import android.util.Log

internal object X05Logger {
    private const val TAG = "VaultGuard:X05"

    fun i(msg: String) = Log.i(TAG, msg)
    fun w(msg: String, tr: Throwable? = null) = Log.w(TAG, msg, tr)
    fun e(msg: String, tr: Throwable? = null) = Log.e(TAG, msg, tr)
}


package com.vaultguard.security.audit

import android.content.Context
import com.vaultguard.security.SecureStorage
import org.json.JSONArray
import org.json.JSONObject

/**
 * Encrypted, tamper-evident audit logger backed by SecureStorage.
 *
 * Storage:
 * - Single encrypted blob fileName = [AUDIT_FILE]
 * - Content = JSON array of entries.
 *
 * Note: This is a baseline; for very high event volume, we can roll segments.
 */
class AuditLogger(
    context: Context,
    private val storage: SecureStorage = SecureStorage(context),
) {
    fun append(eventType: String, data: Map<String, String> = emptyMap()): AuditLogEntry {
        val entries = loadEntriesMutable()
        val prevHash = entries.lastOrNull()?.hashHex ?: GENESIS_HASH
        val ts = System.currentTimeMillis()
        val hash = AuditLogEntry.computeHashHex(ts, eventType, data, prevHash)
        val entry = AuditLogEntry(
            tsEpochMillis = ts,
            eventType = eventType,
            data = data,
            prevHashHex = prevHash,
            hashHex = hash,
        )
        entries.add(entry)
        persist(entries)
        return entry
    }

    fun verify(): Boolean {
        val entries = loadEntries()
        var prev = GENESIS_HASH
        for (e in entries) {
            if (e.prevHashHex != prev) return false
            val expected = AuditLogEntry.computeHashHex(e.tsEpochMillis, e.eventType, e.data, e.prevHashHex)
            if (expected != e.hashHex) return false
            prev = e.hashHex
        }
        return true
    }

    fun readAll(): List<AuditLogEntry> = loadEntries()

    private fun loadEntries(): List<AuditLogEntry> {
        val raw = storage.loadEncryptedDocument(AUDIT_FILE) ?: return emptyList()
        val json = raw.toString(Charsets.UTF_8).takeIf { it.isNotBlank() } ?: return emptyList()
        return runCatching {
            val arr = JSONArray(json)
            (0 until arr.length()).map { idx -> AuditLogEntry.fromJson(arr.getJSONObject(idx)) }
        }.getOrDefault(emptyList())
    }

    private fun loadEntriesMutable(): MutableList<AuditLogEntry> = loadEntries().toMutableList()

    private fun persist(entries: List<AuditLogEntry>) {
        val arr = JSONArray()
        entries.forEach { arr.put(it.toJson()) }
        storage.saveEncryptedDocument(arr.toString().toByteArray(Charsets.UTF_8), AUDIT_FILE)
    }

    companion object {
        private const val AUDIT_FILE = "vaultguard_audit_log"
        private const val GENESIS_HASH = "0000000000000000000000000000000000000000000000000000000000000000"
    }
}


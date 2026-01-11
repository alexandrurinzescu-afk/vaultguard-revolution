package com.vaultguard.security.audit

import org.json.JSONObject
import java.security.MessageDigest

/**
 * Tamper-evident audit log entry using hash chaining.
 *
 * This is a practical alternative to "blockchain-backed logs" that still provides:
 * - ordered, append-only semantics (when stored and appended correctly)
 * - detection of tampering (edits/reordering) via hash-chain verification
 *
 * Store the serialized log encrypted at rest (we do so via SecureStorage).
 */
data class AuditLogEntry(
    val tsEpochMillis: Long,
    val eventType: String,
    val data: Map<String, String>,
    val prevHashHex: String,
    val hashHex: String,
) {
    fun toJson(): JSONObject {
        val o = JSONObject()
        o.put("ts", tsEpochMillis)
        o.put("eventType", eventType)
        val d = JSONObject()
        for ((k, v) in data) d.put(k, v)
        o.put("data", d)
        o.put("prevHash", prevHashHex)
        o.put("hash", hashHex)
        return o
    }

    companion object {
        fun fromJson(o: JSONObject): AuditLogEntry {
            val dataObj = o.optJSONObject("data") ?: JSONObject()
            val data = buildMap {
                val keys = dataObj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    put(k, dataObj.optString(k, ""))
                }
            }
            return AuditLogEntry(
                tsEpochMillis = o.getLong("ts"),
                eventType = o.getString("eventType"),
                data = data,
                prevHashHex = o.getString("prevHash"),
                hashHex = o.getString("hash"),
            )
        }

        fun computeHashHex(ts: Long, eventType: String, data: Map<String, String>, prevHashHex: String): String {
            val canonical = buildString {
                append(ts)
                append('|')
                append(eventType)
                append('|')
                append(prevHashHex)
                append('|')
                // Canonicalize map ordering for deterministic hashes.
                data.toSortedMap().forEach { (k, v) ->
                    append(k)
                    append('=')
                    append(v)
                    append(';')
                }
            }
            val digest = MessageDigest.getInstance("SHA-256").digest(canonical.toByteArray(Charsets.UTF_8))
            return digest.joinToString("") { b -> "%02x".format(b) }
        }
    }
}


package com.vaultguard.security.models

import org.json.JSONObject

/**
 * Metadata for a stored document/ticket.
 *
 * Keep this minimal and versioned so we can evolve formats without breaking stored data.
 */
data class DocumentMetadata(
    val type: String,
    val displayName: String? = null,
    val issuingAuthority: String? = null,
    val issuedAtEpochMillis: Long? = null,
    val expirationEpochMillis: Long? = null,
    val notes: String? = null,
    val schemaVersion: Int = 1,
) {
    fun toJsonString(): String {
        val o = JSONObject()
        o.put("schemaVersion", schemaVersion)
        o.put("type", type)
        if (displayName != null) o.put("displayName", displayName)
        if (issuingAuthority != null) o.put("issuingAuthority", issuingAuthority)
        if (issuedAtEpochMillis != null) o.put("issuedAtEpochMillis", issuedAtEpochMillis)
        if (expirationEpochMillis != null) o.put("expirationEpochMillis", expirationEpochMillis)
        if (notes != null) o.put("notes", notes)
        return o.toString()
    }

    companion object {
        fun fromJsonString(raw: String): DocumentMetadata {
            val o = JSONObject(raw)
            return DocumentMetadata(
                schemaVersion = o.optInt("schemaVersion", 1),
                type = o.getString("type"),
                displayName = o.optStringOrNull("displayName"),
                issuingAuthority = o.optStringOrNull("issuingAuthority"),
                issuedAtEpochMillis = o.optLongOrNull("issuedAtEpochMillis"),
                expirationEpochMillis = o.optLongOrNull("expirationEpochMillis"),
                notes = o.optStringOrNull("notes"),
            )
        }
    }
}

private fun JSONObject.optLongOrNull(key: String): Long? {
    return if (has(key) && !isNull(key)) optLong(key) else null
}

private fun JSONObject.optStringOrNull(key: String): String? {
    return if (has(key) && !isNull(key)) optString(key) else null
}


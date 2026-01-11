package com.vaultguard.document

import org.json.JSONObject
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

data class DocumentData(
    val id: String,
    val type: DocumentType,
    /**
     * For now this is an internal path (e.g. cache path) captured at scan time.
     * The encrypted image is stored via SecureStorage in DocumentRepository.
     */
    val originalImageUri: String,
    val extractedText: Map<String, String>,
    val scanDate: LocalDateTime,
    val expirationDate: LocalDateTime?,
    val isVerified: Boolean = false,
    val biometricBindingId: String? = null,
) {
    fun toJsonString(): String {
        val o = JSONObject()
        o.put("id", id)
        o.put("type", type.name)
        o.put("originalImageUri", originalImageUri)
        o.put("scanDateEpochMillis", scanDate.toEpochMillis())
        if (expirationDate != null) o.put("expirationDateEpochMillis", expirationDate.toEpochMillis())
        o.put("isVerified", isVerified)
        if (biometricBindingId != null) o.put("biometricBindingId", biometricBindingId)

        val extracted = JSONObject()
        for ((k, v) in extractedText) extracted.put(k, v)
        o.put("extractedText", extracted)
        return o.toString()
    }

    companion object {
        fun fromJsonString(raw: String): DocumentData {
            val o = JSONObject(raw)
            val extractedObj = o.optJSONObject("extractedText") ?: JSONObject()
            val extracted = buildMap {
                val keys = extractedObj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    put(k, extractedObj.optString(k, ""))
                }
            }
            return DocumentData(
                id = o.getString("id"),
                type = DocumentType.valueOf(o.getString("type")),
                originalImageUri = o.optString("originalImageUri", ""),
                extractedText = extracted,
                scanDate = epochMillisToLocalDateTime(o.getLong("scanDateEpochMillis")),
                expirationDate = if (o.has("expirationDateEpochMillis") && !o.isNull("expirationDateEpochMillis")) {
                    epochMillisToLocalDateTime(o.getLong("expirationDateEpochMillis"))
                } else {
                    null
                },
                isVerified = o.optBoolean("isVerified", false),
                biometricBindingId = o.optString("biometricBindingId").takeIf { it.isNotBlank() },
            )
        }
    }
}

private fun LocalDateTime.toEpochMillis(zoneId: ZoneId = ZoneId.systemDefault()): Long {
    return atZone(zoneId).toInstant().toEpochMilli()
}

private fun epochMillisToLocalDateTime(epochMillis: Long, zoneId: ZoneId = ZoneId.systemDefault()): LocalDateTime {
    return LocalDateTime.ofInstant(Instant.ofEpochMilli(epochMillis), zoneId)
}


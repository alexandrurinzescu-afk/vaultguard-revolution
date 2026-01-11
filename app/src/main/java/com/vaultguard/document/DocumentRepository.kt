package com.vaultguard.document

import android.content.Context
import com.vaultguard.security.SecureStorage
import com.vaultguard.security.models.DocumentMetadata
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.UUID

/**
 * Repository for document scanning module (v2.1.6).
 *
 * Storage model:
 * - The encrypted JPEG bytes are stored via [SecureStorage.saveDocumentWithMetadata] under [DocumentData.id]
 * - Structured fields are stored inside encrypted metadata's [DocumentMetadata.notes] as JSON.
 *
 * This keeps storage simple (one blob + one metadata record per document) and leverages the existing
 * encrypted metadata channel for search/list.
 */
class DocumentRepository(
    context: Context,
    private val secureStorage: SecureStorage = SecureStorage(context),
) {
    fun saveScannedDocument(
        type: DocumentType,
        jpegBytes: ByteArray,
        extractedText: Map<String, String>,
        originalImageUri: String,
        expirationDate: LocalDateTime? = null,
        isVerified: Boolean = false,
        biometricBindingId: String? = null,
    ): DocumentData {
        val now = LocalDateTime.now()
        val id = newId()

        val notesJson = JSONObject().apply {
            put("schemaVersion", 1)
            put("originalImageUri", originalImageUri)
            put("scanDateEpochMillis", now.toEpochMillis())
            if (expirationDate != null) put("expirationDateEpochMillis", expirationDate.toEpochMillis())
            put("isVerified", isVerified)
            if (!biometricBindingId.isNullOrBlank()) put("biometricBindingId", biometricBindingId)

            val extracted = JSONObject()
            for ((k, v) in extractedText) extracted.put(k, v)
            put("extractedText", extracted)
        }.toString()

        val metadata = DocumentMetadata(
            type = type.name,
            displayName = "${type.name.lowercase()}_${now.toEpochMillis()}",
            issuedAtEpochMillis = now.toEpochMillis(),
            expirationEpochMillis = expirationDate?.toEpochMillis(),
            notes = notesJson,
            schemaVersion = 2,
        )

        secureStorage.saveDocumentWithMetadata(
            data = jpegBytes,
            fileName = id,
            metadata = metadata,
        )

        return DocumentData(
            id = id,
            type = type,
            originalImageUri = originalImageUri,
            extractedText = extractedText,
            scanDate = now,
            expirationDate = expirationDate,
            isVerified = isVerified,
            biometricBindingId = biometricBindingId,
        )
    }

    fun listDocuments(): List<DocumentData> {
        return secureStorage.listStoredDocuments()
            .mapNotNull { id -> getDocument(id) }
            .sortedByDescending { it.scanDate }
    }

    fun getDocument(id: String): DocumentData? {
        val meta = secureStorage.getDocumentMetadata(id) ?: return null
        val type = runCatching { DocumentType.valueOf(meta.type) }.getOrNull() ?: DocumentType.OTHER

        val notes = meta.notes
        if (notes.isNullOrBlank()) {
            // Best-effort fallback for older encrypted blobs with minimal metadata.
            val scanDate = meta.issuedAtEpochMillis?.let { epochMillisToLocalDateTime(it) } ?: LocalDateTime.now()
            val exp = meta.expirationEpochMillis?.let { epochMillisToLocalDateTime(it) }
            return DocumentData(
                id = id,
                type = type,
                originalImageUri = "",
                extractedText = emptyMap(),
                scanDate = scanDate,
                expirationDate = exp,
                isVerified = false,
                biometricBindingId = null,
            )
        }

        return runCatching {
            val o = JSONObject(notes)
            val extractedObj = o.optJSONObject("extractedText") ?: JSONObject()
            val extracted = buildMap {
                val keys = extractedObj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    put(k, extractedObj.optString(k, ""))
                }
            }
            val scanDate = epochMillisToLocalDateTime(o.optLong("scanDateEpochMillis", meta.issuedAtEpochMillis ?: System.currentTimeMillis()))
            val exp = if (o.has("expirationDateEpochMillis") && !o.isNull("expirationDateEpochMillis")) {
                epochMillisToLocalDateTime(o.getLong("expirationDateEpochMillis"))
            } else {
                meta.expirationEpochMillis?.let { epochMillisToLocalDateTime(it) }
            }

            DocumentData(
                id = id,
                type = type,
                originalImageUri = o.optString("originalImageUri", ""),
                extractedText = extracted,
                scanDate = scanDate,
                expirationDate = exp,
                isVerified = o.optBoolean("isVerified", false),
                biometricBindingId = o.optString("biometricBindingId").takeIf { it.isNotBlank() },
            )
        }.getOrNull()
    }

    fun loadDecryptedImage(id: String): ByteArray? {
        return secureStorage.loadEncryptedDocument(id)
    }

    fun delete(id: String): Boolean {
        return secureStorage.deleteStoredDocument(id)
    }

    /**
     * Search by type and also by extracted field values (decrypting metadata only).
     */
    fun search(
        type: DocumentType? = null,
        query: String? = null,
    ): List<DocumentData> {
        val normalizedQuery = query?.trim()?.takeIf { it.isNotEmpty() }?.lowercase()

        val ids = if (type != null) {
            secureStorage.searchByType(type.name)
        } else {
            secureStorage.listStoredDocuments()
        }

        if (normalizedQuery == null) {
            return ids.mapNotNull { getDocument(it) }
        }

        return ids.mapNotNull { getDocument(it) }
            .filter { doc ->
                doc.type.name.lowercase().contains(normalizedQuery) ||
                    doc.extractedText.any { (k, v) ->
                        k.lowercase().contains(normalizedQuery) || v.lowercase().contains(normalizedQuery)
                    }
            }
    }

    private fun newId(): String = "doc_${UUID.randomUUID()}"
}

private fun LocalDateTime.toEpochMillis(zoneId: ZoneId = ZoneId.systemDefault()): Long {
    return atZone(zoneId).toInstant().toEpochMilli()
}

private fun epochMillisToLocalDateTime(epochMillis: Long, zoneId: ZoneId = ZoneId.systemDefault()): LocalDateTime {
    return LocalDateTime.ofInstant(Instant.ofEpochMilli(epochMillis), zoneId)
}


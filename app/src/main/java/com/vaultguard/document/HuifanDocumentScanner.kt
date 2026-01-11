package com.vaultguard.document

import android.net.Uri

/**
 * Preparation hook for Huifan SDK integration (v2.1.6).
 *
 * When devices arrive, implement this interface with the real Huifan capture pipeline and/or OCR.
 */
interface HuifanDocumentScanner {
    suspend fun captureDocument(type: DocumentType): CaptureResult

    data class CaptureResult(
        val imageUri: Uri,
        val type: DocumentType,
    )
}


package com.vaultguard.document

import android.content.Context
import android.net.Uri

/**
 * Mock implementation for testing flows before Huifan hardware arrives.
 *
 * It returns a provided [mockImageUri] (e.g. from gallery pick / test asset).
 */
class HuifanDocumentScannerMock(
    private val context: Context,
    private val mockImageUri: Uri,
) : HuifanDocumentScanner {
    override suspend fun captureDocument(type: DocumentType): HuifanDocumentScanner.CaptureResult {
        // In real SDK integration, we'd trigger the device capture and return the saved image Uri.
        return HuifanDocumentScanner.CaptureResult(imageUri = mockImageUri, type = type)
    }
}


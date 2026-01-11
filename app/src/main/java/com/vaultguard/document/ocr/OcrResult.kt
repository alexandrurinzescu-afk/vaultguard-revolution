package com.vaultguard.document.ocr

/**
 * Result of OCR processing.
 *
 * NOTE: ML Kit does not provide a reliable global confidence score across all recognizers.
 * We compute a practical heuristic confidence in [0.0, 1.0] to drive fallback logic.
 */
data class OcrResult(
    val text: String,
    val recognizer: Recognizer,
    val confidence: Double,
    val diagnostics: Map<String, String> = emptyMap(),
) {
    enum class Recognizer {
        LATIN,
        CHINESE,
        DEVANAGARI,
        JAPANESE,
        KOREAN,
    }
}


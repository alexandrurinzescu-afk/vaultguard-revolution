package com.vaultguard.document.ocr

import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.tasks.await
import java.util.Locale

/**
 * Global multi-language OCR engine (SUBPUNCT 2.3.2).
 *
 * Strategy:
 * - Choose a likely script from fast heuristics (based on already-read raw text if present).
 * - Run the most likely recognizer first; if confidence is poor, try a bounded fallback set.
 *
 * This keeps performance sane while supporting multiple scripts.
 */
class OcrEngine(
    private val maxFallbackRecognizers: Int = 2,
) {
    private val latin: TextRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private val chinese: TextRecognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    private val devanagari: TextRecognizer = TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build())
    private val japanese: TextRecognizer = TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
    private val korean: TextRecognizer = TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())

    suspend fun recognize(image: InputImage): OcrResult {
        // Start with Latin; it's the most common and the cheapest dependency-wise.
        val primary = runRecognizer(image, OcrResult.Recognizer.LATIN, latin)

        val guess = guessScriptFromText(primary.text)
        val ordered = when (guess) {
            OcrResult.Recognizer.CHINESE -> listOf(OcrResult.Recognizer.CHINESE, OcrResult.Recognizer.JAPANESE, OcrResult.Recognizer.LATIN)
            OcrResult.Recognizer.DEVANAGARI -> listOf(OcrResult.Recognizer.DEVANAGARI, OcrResult.Recognizer.LATIN)
            OcrResult.Recognizer.JAPANESE -> listOf(OcrResult.Recognizer.JAPANESE, OcrResult.Recognizer.CHINESE, OcrResult.Recognizer.LATIN)
            OcrResult.Recognizer.KOREAN -> listOf(OcrResult.Recognizer.KOREAN, OcrResult.Recognizer.LATIN)
            OcrResult.Recognizer.LATIN -> listOf(OcrResult.Recognizer.LATIN)
        }

        // If primary already looks good, keep it.
        if (primary.confidence >= 0.85 && primary.text.length >= 20) return primary

        val candidates = ArrayList<OcrResult>(1 + maxFallbackRecognizers)
        candidates.add(primary)

        val fallbacks = ordered
            .filterNot { it == OcrResult.Recognizer.LATIN } // already ran Latin
            .take(maxFallbackRecognizers)

        for (r in fallbacks) {
            val o = when (r) {
                OcrResult.Recognizer.CHINESE -> runRecognizer(image, r, chinese)
                OcrResult.Recognizer.DEVANAGARI -> runRecognizer(image, r, devanagari)
                OcrResult.Recognizer.JAPANESE -> runRecognizer(image, r, japanese)
                OcrResult.Recognizer.KOREAN -> runRecognizer(image, r, korean)
                OcrResult.Recognizer.LATIN -> primary
            }
            candidates.add(o)
        }

        return candidates.maxBy { it.confidence }
    }

    private suspend fun runRecognizer(image: InputImage, tag: OcrResult.Recognizer, recognizer: TextRecognizer): OcrResult {
        val r = recognizer.process(image).await()
        val text = r.text.orEmpty()
        val confidence = estimateConfidence(text)
        return OcrResult(
            text = text,
            recognizer = tag,
            confidence = confidence,
            diagnostics = mapOf(
                "len" to text.length.toString(),
                "nonAsciiRatio" to "%.2f".format(Locale.ROOT, nonAsciiRatio(text)),
            ),
        )
    }

    private fun guessScriptFromText(text: String): OcrResult.Recognizer {
        // Very cheap heuristic from recognized Unicode blocks.
        val counts = mutableMapOf<OcrResult.Recognizer, Int>()
        fun inc(r: OcrResult.Recognizer) {
            counts[r] = (counts[r] ?: 0) + 1
        }
        for (ch in text) {
            when (Character.UnicodeBlock.of(ch)) {
                Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS,
                Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS_EXTENSION_A,
                Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS_EXTENSION_B,
                Character.UnicodeBlock.CJK_COMPATIBILITY_IDEOGRAPHS,
                -> inc(OcrResult.Recognizer.CHINESE)

                Character.UnicodeBlock.HIRAGANA,
                Character.UnicodeBlock.KATAKANA,
                Character.UnicodeBlock.KATAKANA_PHONETIC_EXTENSIONS,
                -> inc(OcrResult.Recognizer.JAPANESE)

                Character.UnicodeBlock.HANGUL_JAMO,
                Character.UnicodeBlock.HANGUL_COMPATIBILITY_JAMO,
                Character.UnicodeBlock.HANGUL_SYLLABLES,
                -> inc(OcrResult.Recognizer.KOREAN)

                Character.UnicodeBlock.DEVANAGARI -> inc(OcrResult.Recognizer.DEVANAGARI)
            }
        }

        val best = counts.maxByOrNull { it.value }?.key
        return best ?: OcrResult.Recognizer.LATIN
    }

    private fun estimateConfidence(text: String): Double {
        if (text.isBlank()) return 0.0

        val total = text.length.coerceAtLeast(1)
        val lettersOrDigits = text.count { it.isLetterOrDigit() }
        val printable = text.count { !it.isISOControl() }
        val weird = text.count { it == '�' || it == '?' }

        val alphaRatio = lettersOrDigits.toDouble() / total
        val printableRatio = printable.toDouble() / total
        val weirdPenalty = (weird.toDouble() / total) * 0.6

        // Favor longer texts but cap.
        val lenBonus = (text.trim().length / 120.0).coerceIn(0.0, 1.0) * 0.25

        val base = (alphaRatio * 0.55) + (printableRatio * 0.35) + lenBonus - weirdPenalty
        return base.coerceIn(0.0, 1.0)
    }

    private fun nonAsciiRatio(text: String): Double {
        if (text.isEmpty()) return 0.0
        val non = text.count { it.code > 0x7F }
        return non.toDouble() / text.length.toDouble()
    }
}


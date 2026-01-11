package com.vaultguard.document.ocr

import android.content.Context
import com.vaultguard.document.DocumentType
import com.vaultguard.security.SecureStorage
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

/**
 * AI Enhancement Layer (SUBPUNCT 2.3.2)
 *
 * Reality:
 * - We don't have an on-device LLM in this repo yet.
 * - This enhancer is a deterministic "AI-like" post-processor:
 *   - fixes common OCR confusions (0/O, 1/I/l, 5/S, 8/B, etc.)
 *   - uses document context dictionaries (PASSPORT, VISA, MRZ markers, etc.)
 *   - optionally learns from user corrections (local-only, encrypted via SecureStorage)
 *
 * Outputs a new text + a confidence delta estimate.
 */
class OcrEnhancer(
    private val storage: SecureStorage,
) {
    data class EnhancedResult(
        val text: String,
        val confidence: Double,
        val appliedRules: List<String>,
    )

    fun enhance(context: Context, original: OcrResult, docTypeHint: DocumentType? = null): EnhancedResult {
        var t = original.text
        val applied = ArrayList<String>(8)

        // Apply learned corrections first (most personalized).
        val learned = loadLearnedCorrections()
        if (learned.isNotEmpty()) {
            val before = t
            for ((from, to) in learned) {
                if (from.isNotBlank() && to.isNotBlank()) {
                    t = t.replace(from, to, ignoreCase = false)
                }
            }
            if (t != before) applied.add("learned_corrections")
        }

        // Global common OCR confusion fixes (bounded and conservative).
        val beforeGlobal = t
        t = fixCommonConfusions(t, applied)
        if (t != beforeGlobal) {
            // already recorded inside fixCommonConfusions
        }

        // Context-aware dictionary boosts.
        val beforeDict = t
        val dict = dictionaryFor(docTypeHint)
        if (dict.isNotEmpty()) {
            val normalized = t
            for ((bad, good) in dict) {
                t = t.replace(bad, good, ignoreCase = true)
            }
            if (t != normalized) applied.add("context_dictionary")
        }

        val conf = enhanceConfidenceEstimate(original.confidence, original.text, t)
        return EnhancedResult(text = t, confidence = conf, appliedRules = applied)
    }

    /**
     * Feedback loop: call when user confirms a correction. Stored encrypted at rest.
     */
    fun recordUserCorrection(from: String, to: String) {
        val cleanedFrom = from.trim().take(64)
        val cleanedTo = to.trim().take(64)
        if (cleanedFrom.isBlank() || cleanedTo.isBlank() || cleanedFrom == cleanedTo) return

        val existing = loadLearnedCorrections().toMutableList()
        existing.removeAll { it.first == cleanedFrom }
        existing.add(0, cleanedFrom to cleanedTo)
        persistLearnedCorrections(existing.take(MAX_LEARNED))
    }

    private fun fixCommonConfusions(text: String, applied: MutableList<String>): String {
        var t = text

        // Common word-level corrections
        val beforeWords = t
        val wordFixes = mapOf(
            "PAS5PORT" to "PASSPORT",
            "PA55PORT" to "PASSPORT",
            "V1SA" to "VISA",
            "MA5TERCARD" to "MASTERCARD",
        )
        for ((bad, good) in wordFixes) {
            t = t.replace(bad, good, ignoreCase = true)
        }
        if (t != beforeWords) applied.add("word_fixes")

        // Character-level corrections in likely-alphanumeric tokens (avoid rewriting free text too much).
        val beforeTokens = t
        t = t.splitToSequence('\n')
            .joinToString("\n") { line ->
                line.split(Regex("""(\s+)"""))
                    .joinToString("") { token ->
                        if (token.length >= 6 && token.count { it.isLetterOrDigit() } >= (token.length * 0.7)) {
                            token
                                .replace('O', '0') // often numbers
                                .replace('I', '1')
                                .replace('l', '1')
                        } else {
                            token
                        }
                    }
            }
        if (t != beforeTokens) applied.add("token_char_fixes")

        return t
    }

    private fun dictionaryFor(type: DocumentType?): Map<String, String> {
        return when (type) {
            DocumentType.PASSPORT -> mapOf(
                "passeport" to "PASSPORT",
                "pas5port" to "PASSPORT",
                "pasaport" to "PASSPORT",
            )
            DocumentType.CREDIT_CARD -> mapOf(
                "valid thru" to "VALID THRU",
                "valid through" to "VALID THRU",
                "card holder" to "CARDHOLDER",
            )
            DocumentType.TICKET -> mapOf(
                "admit one" to "ADMIT ONE",
                "entr\\u00e9e" to "ENTRÉE",
            )
            else -> emptyMap()
        }
    }

    private fun enhanceConfidenceEstimate(base: Double, before: String, after: String): Double {
        if (before == after) return base

        // Improvement heuristics:
        // - fewer weird chars
        // - more alnum density
        val beforeWeird = before.count { it == '�' || it == '?' }
        val afterWeird = after.count { it == '�' || it == '?' }

        val beforeAlpha = before.count { it.isLetterOrDigit() }.toDouble() / (before.length.coerceAtLeast(1))
        val afterAlpha = after.count { it.isLetterOrDigit() }.toDouble() / (after.length.coerceAtLeast(1))

        var delta = 0.0
        if (afterWeird < beforeWeird) delta += 0.05
        if (afterAlpha > beforeAlpha + 0.02) delta += 0.03

        return (base + delta).coerceIn(0.0, 1.0)
    }

    private fun loadLearnedCorrections(): List<Pair<String, String>> {
        val raw = storage.loadEncryptedDocument(LEARNED_FILE)?.toString(Charsets.UTF_8) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.getJSONObject(i)
                val from = o.optString("from", "").takeIf { it.isNotBlank() } ?: return@mapNotNull null
                val to = o.optString("to", "").takeIf { it.isNotBlank() } ?: return@mapNotNull null
                from to to
            }
        }.getOrDefault(emptyList())
    }

    private fun persistLearnedCorrections(pairs: List<Pair<String, String>>) {
        val arr = JSONArray()
        for ((from, to) in pairs) {
            val o = JSONObject()
            o.put("from", from)
            o.put("to", to)
            arr.put(o)
        }
        storage.saveEncryptedDocument(arr.toString().toByteArray(Charsets.UTF_8), LEARNED_FILE)
    }

    private companion object {
        private const val LEARNED_FILE = "ocr_learned_corrections"
        private const val MAX_LEARNED = 200
    }
}


package com.vaultguard.document

import java.util.Locale

/**
 * SUBPUNCT 2.3.1 — Document auto-classification (global).
 *
 * IMPORTANT REALITY CHECK:
 * - Achieving "95%+ globally" requires a curated dataset + evaluation harness.
 * - This implementation provides a strong on-device baseline using globally robust signals:
 *   MRZ detection (passport), Luhn-valid PAN (credit card), barcode/QR presence + ticket keywords,
 *   and multilingual ID keywords.
 *
 * It returns a type + confidence + evidence signals so we can later benchmark and tune.
 */
object DocumentAutoClassifier {
    data class Classification(
        val type: DocumentType,
        val confidence: Double,
        val signals: Map<String, Double>,
    )

    fun classify(rawText: String, barcodes: List<String>): Classification {
        val text = rawText
            .replace('\u00A0', ' ')
            .trim()

        val lower = text.lowercase(Locale.ROOT)

        val signals = LinkedHashMap<String, Double>()

        // Passport signals (MRZ is the strongest global indicator)
        val mrzScore = if (containsMrz(text)) 0.95 else 0.0
        if (mrzScore > 0) signals["passport_mrz"] = mrzScore
        val passportKw = keywordScore(
            lower,
            keywords = listOf(
                "passport", "passeport", "pasaporte", "passaporto", "reisepass",
                "j\\u00e4senkirja", // Finnish-ish (example)
                "جواز", "سفر", // Arabic hints
                "护照", "パスポート", "여권", "паспорт", "תעודת מעבר"
            ),
            weight = 0.35
        )
        if (passportKw > 0) signals["passport_keywords"] = passportKw

        // Credit card signals (PAN + Luhn is strongest)
        val luhnScore = if (containsLuhnPan(text)) 0.95 else 0.0
        if (luhnScore > 0) signals["card_luhn_pan"] = luhnScore
        val cardKw = keywordScore(
            lower,
            keywords = listOf(
                "visa", "mastercard", "amex", "american express", "unionpay", "discover",
                "valid thru", "valid through", "good thru", "expires end",
                "ccv", "cvv", "cardholder",
                "有效期", "银行卡", "信用卡", "بطاقة", "بطاقة ائتمان"
            ),
            weight = 0.25
        )
        if (cardKw > 0) signals["card_keywords"] = cardKw

        // Ticket signals (barcode presence helps a lot; tickets often contain QR)
        val barcodeScore = when {
            barcodes.isNotEmpty() -> 0.70
            else -> 0.0
        }
        if (barcodeScore > 0) signals["ticket_barcode_present"] = barcodeScore
        val ticketKw = keywordScore(
            lower,
            keywords = listOf(
                "ticket", "admit", "admission", "entry", "gate", "venue",
                "seat", "row", "section", "zone", "tribune",
                "billet", "entr\\u00e9e", "plac\\u00e9", // FR
                "bilet", "intrare", // RO
                "entrada", "boleto", // ES/PT-ish
                "билет", "вход", // Cyrillic
                "票", "入场", "入場", "チケット", "입장", "تذكرة"
            ),
            weight = 0.40
        )
        if (ticketKw > 0) signals["ticket_keywords"] = ticketKw

        // ID card signals (multilingual keywords; less "globally unique" than MRZ/Luhn)
        val idStrongMarkerHit = containsAnyLiteral(
            lower,
            listOf(
                "cnp",
                "national id",
                "id card",
                "identity card",
                "identification card",
                "carte de identitate",
                "carte identitate",
                "buletin",
                "personalausweis",
                "documento de identidad",
                "身份证",
                "居民身份证",
            ),
        )
        val idStrongMarker = if (idStrongMarkerHit) 0.75 else 0.0
        if (idStrongMarker > 0) signals["id_strong_marker"] = idStrongMarker

        val idWeakMarker = keywordScore(
            lower,
            keywords = listOf(
                "identity", "identification", "identit", "identit\\u00e9",
                "date of birth", "dob", "birth", "naissance", "n\\u0103scut", "data na\\u0219terii"
            ),
            weight = 0.20
        )
        if (idWeakMarker > 0) signals["id_weak_marker"] = idWeakMarker

        // Aggregate scores per class (cap at 1.0).
        val passportScoreTotal = cap01(mrzScore + passportKw)
        val cardScoreTotal = cap01(luhnScore + cardKw)
        val ticketScoreTotal = cap01(barcodeScore + ticketKw)
        val idScoreTotal = cap01(idStrongMarker + idWeakMarker)

        val scored = listOf(
            DocumentType.PASSPORT to passportScoreTotal,
            DocumentType.CREDIT_CARD to cardScoreTotal,
            DocumentType.TICKET to ticketScoreTotal,
            DocumentType.ID_CARD to idScoreTotal,
        ).sortedByDescending { it.second }

        val (bestType, bestScore) = scored.first()

        // If we don't have strong evidence, fall back to OTHER.
        val finalType = if (bestScore < 0.55) DocumentType.OTHER else bestType

        return Classification(
            type = finalType,
            confidence = bestScore,
            signals = signals,
        )
    }

    private fun keywordScore(textLower: String, keywords: List<String>, weight: Double): Double {
        if (textLower.isBlank()) return 0.0
        var hits = 0
        for (kw in keywords) {
            // Some entries are regex-ish; keep it simple but tolerant.
            val normalizedKw = kw.lowercase(Locale.ROOT)
            if (normalizedKw.contains("\\s") || normalizedKw.contains("\\u")) {
                // Best-effort: treat as regex.
                runCatching {
                    if (Regex(normalizedKw, RegexOption.IGNORE_CASE).containsMatchIn(textLower)) hits++
                }
            } else {
                if (textLower.contains(normalizedKw)) hits++
            }
        }
        if (hits == 0) return 0.0
        // Saturating score: more hits quickly reaches the max weight.
        val scaled = (hits / 4.0).coerceAtMost(1.0) * weight
        return cap01(scaled)
    }

    private fun containsAnyLiteral(textLower: String, needles: List<String>): Boolean {
        if (textLower.isBlank()) return false
        return needles.any { n -> n.isNotBlank() && textLower.contains(n.lowercase(Locale.ROOT)) }
    }

    private fun containsMrz(text: String): Boolean {
        // ICAO MRZ: two lines (usually 2) with only A-Z0-9< and fixed lengths (30/36/44).
        val lines = text.lines()
            .map { it.trim().replace(" ", "") }
            .filter { it.length >= 30 }

        val mrzLine = Regex("""^[A-Z0-9<]{30,60}$""")
        val candidates = lines.filter { mrzLine.matches(it) }
        if (candidates.size < 2) return false

        // Prefer finding two consecutive MRZ-like lines (common passport pattern).
        for (i in 0 until lines.size - 1) {
            if (mrzLine.matches(lines[i]) && mrzLine.matches(lines[i + 1])) return true
        }
        return true
    }

    private fun containsLuhnPan(text: String): Boolean {
        // Match sequences that may contain spaces/hyphens but represent a 13-19 digit PAN overall.
        val panLike = Regex("""(?:\d[ -]?){13,22}""")
        val candidates = panLike.findAll(text).mapNotNull { m ->
            val digits = m.value.filter { it.isDigit() }
            digits.takeIf { it.length in 13..19 }
        }.toList()

        return candidates.any { isValidLuhn(it) }
    }

    private fun isValidLuhn(number: String): Boolean {
        if (number.any { !it.isDigit() }) return false
        var sum = 0
        var alternate = false
        for (i in number.length - 1 downTo 0) {
            var n = number[i].digitToInt()
            if (alternate) {
                n *= 2
                if (n > 9) n -= 9
            }
            sum += n
            alternate = !alternate
        }
        return sum % 10 == 0
    }

    private fun cap01(v: Double): Double = v.coerceIn(0.0, 1.0)
}


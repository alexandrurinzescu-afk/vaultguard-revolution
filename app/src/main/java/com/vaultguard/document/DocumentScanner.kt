package com.vaultguard.document

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.vaultguard.document.ocr.OcrEngine
import com.vaultguard.document.ocr.OcrEnhancer
import com.vaultguard.security.SecureStorage
import kotlinx.coroutines.tasks.await
import java.time.LocalDateTime
import java.util.Locale

/**
 * Main scanner logic (v2.1.6): OCR + lightweight field extraction.
 *
 * Note: "edge detection / cropping" is intentionally a stub in this first pass.
 * We run OCR on the full captured image to get a working end-to-end flow.
 */
class DocumentScanner {
    private val barcodeScanner = BarcodeScanning.getClient()
    private val ocrEngine = OcrEngine()

    data class ScanResult(
        val rawText: String,
        val enhancedText: String,
        val extractedFields: Map<String, String>,
        val inferredExpiration: LocalDateTime?,
        val barcodes: List<String>,
        val inferredType: DocumentType,
        val classificationConfidence: Double,
        val ocrConfidence: Double,
        val enhancedOcrConfidence: Double,
    )

    suspend fun scan(context: Context, imageUri: Uri, type: DocumentType): ScanResult {
        val bitmap = loadBitmap(context, imageUri)
        val cropped = cropDocument(bitmap) // TODO: add real edge detection / perspective correction
        val input = InputImage.fromBitmap(cropped, 0)
        val barcodeTask = barcodeScanner.process(input)

        val barcodeResult = barcodeTask.await()

        val ocr = ocrEngine.recognize(input)
        val raw = ocr.text
        val barcodes = barcodeResult
            .mapNotNull { it.rawValue?.trim() }
            .filter { it.isNotBlank() }
            .distinct()

        val classification = DocumentAutoClassifier.classify(raw, barcodes)
        val inferredType = classification.type
        val effectiveType = if (type == DocumentType.AUTO) inferredType else type

        val enhancer = OcrEnhancer(SecureStorage(context))
        val enhanced = enhancer.enhance(context, ocr, docTypeHint = effectiveType)
        val enhancedText = enhanced.text

        val extracted = extractFields(enhancedText, effectiveType)
        val exp = parseExpiration(extracted, enhancedText)
        val withBarcode = if (barcodes.isEmpty()) extracted else extracted + mapOf("barcode_data" to barcodes.joinToString(" | "))
        val withClassification = withBarcode +
            mapOf(
                "inferred_type" to inferredType.name,
                "classification_confidence" to "%.2f".format(Locale.ROOT, classification.confidence),
                "ocr_recognizer" to ocr.recognizer.name,
                "ocr_confidence" to "%.2f".format(Locale.ROOT, ocr.confidence),
                "enhanced_ocr_confidence" to "%.2f".format(Locale.ROOT, enhanced.confidence),
            )

        return ScanResult(
            rawText = raw,
            enhancedText = enhancedText,
            extractedFields = withClassification,
            inferredExpiration = exp,
            barcodes = barcodes,
            inferredType = inferredType,
            classificationConfidence = classification.confidence,
            ocrConfidence = ocr.confidence,
            enhancedOcrConfidence = enhanced.confidence,
        )
    }

    private fun loadBitmap(context: Context, uri: Uri): Bitmap {
        context.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open image input stream for $uri" }
            return BitmapFactory.decodeStream(input)
        }
    }

    private fun cropDocument(bitmap: Bitmap): Bitmap {
        // Placeholder: keep full image for now.
        return bitmap
    }

    private fun extractFields(rawText: String, type: DocumentType): Map<String, String> {
        val normalized = rawText.replace('\u00A0', ' ')
        return when (type) {
            DocumentType.AUTO -> mapOf("text" to normalized.trim())
            DocumentType.ID_CARD -> extractIdCard(normalized)
            DocumentType.PASSPORT -> extractPassport(normalized)
            DocumentType.DRIVER_LICENSE -> extractDriverLicense(normalized)
            DocumentType.TICKET -> extractTicket(normalized)
            DocumentType.CREDIT_CARD -> extractCreditCard(normalized)
            DocumentType.OTHER -> mapOf("text" to normalized.trim())
        }
    }

    private fun extractIdCard(text: String): Map<String, String> {
        val idNumber = findFirst(text, Regex("""\b[A-Z0-9]{6,15}\b"""))
        val expiry = findFirst(text, Regex("""\b(?:EXP|EXPIRES|VALID UNTIL|VALABIL PANA LA)\b[:\s]*([0-3]?\d[./-][01]?\d[./-](?:\d{2}|\d{4}))""", RegexOption.IGNORE_CASE), group = 1)
        val name = guessNameFromLines(text)
        return buildMap {
            if (name != null) put("name", name)
            if (idNumber != null) put("id_number", idNumber)
            if (expiry != null) put("expiration_date", expiry)
        }
    }

    private fun extractPassport(text: String): Map<String, String> {
        val passportNo = findFirst(text, Regex("""\b[A-Z0-9]{6,9}\b"""))
        val nationality = findFirst(text, Regex("""\bNATIONALITY\b[:\s]*([A-Z]{3,}|[A-Z][a-z]+)""", RegexOption.IGNORE_CASE), group = 1)
        val dob = findFirst(text, Regex("""\b(?:DATE OF BIRTH|DOB)\b[:\s]*([0-3]?\d[./-][01]?\d[./-](?:\d{2}|\d{4}))""", RegexOption.IGNORE_CASE), group = 1)
        return buildMap {
            if (passportNo != null) put("passport_number", passportNo)
            if (nationality != null) put("nationality", nationality)
            if (dob != null) put("date_of_birth", dob)
        }
    }

    private fun extractDriverLicense(text: String): Map<String, String> {
        val licenseNo = findFirst(text, Regex("""\b(?:DL|LIC|LICENSE)\b[:\s-]*([A-Z0-9]{5,20})""", RegexOption.IGNORE_CASE), group = 1)
        val expiry = findFirst(text, Regex("""\b(?:EXP|EXPIRES)\b[:\s]*([0-3]?\d[./-][01]?\d[./-](?:\d{2}|\d{4}))""", RegexOption.IGNORE_CASE), group = 1)
        val name = guessNameFromLines(text)
        return buildMap {
            if (name != null) put("name", name)
            if (licenseNo != null) put("license_number", licenseNo)
            if (expiry != null) put("expiration_date", expiry)
        }
    }

    private fun extractTicket(text: String): Map<String, String> {
        val lines = text.lines().map { it.trim() }.filter { it.isNotBlank() }
        val eventName = lines.firstOrNull()?.takeIf { it.length >= 4 }
        val seat = findFirst(text, Regex("""\b(?:SEAT|ROW|SECTION)\b[:\s-]*([A-Z0-9\- ]{2,20})""", RegexOption.IGNORE_CASE), group = 1)
        val date = findFirst(text, Regex("""\b([0-3]?\d[./-][01]?\d[./-](?:\d{2}|\d{4}))\b"""))
        return buildMap {
            if (eventName != null) put("event_name", eventName)
            if (seat != null) put("seat", seat.trim())
            if (date != null) put("date", date)
            // TODO: QR code data requires ML Kit barcode scanning.
        }
    }

    private fun extractCreditCard(text: String): Map<String, String> {
        val cardNumberRaw = findFirst(text, Regex("""\b(?:\d[ -]*?){13,19}\b"""))
        val masked = cardNumberRaw?.let { maskCardNumber(it) }
        val expiry = findFirst(text, Regex("""\b(0[1-9]|1[0-2])\s*[/.-]\s*(\d{2}|\d{4})\b"""))
        val name = guessNameFromLines(text)
        return buildMap {
            if (masked != null) put("card_number_masked", masked)
            if (expiry != null) put("expiration", expiry.replace(" ", ""))
            if (name != null) put("name", name)
        }
    }

    private fun parseExpiration(extracted: Map<String, String>, raw: String): LocalDateTime? {
        val candidate = extracted["expiration_date"] ?: extracted["expiration"]
        // Keep as null for now (parsing formats reliably is non-trivial).
        // We’ll store the raw string field and later enhance with locale-aware parsing.
        return if (candidate.isNullOrBlank()) null else null
    }

    private fun guessNameFromLines(text: String): String? {
        val lines = text.lines()
            .map { it.trim() }
            .filter { it.length in 4..60 }
            .filter { it.any { ch -> ch.isLetter() } }
            .filterNot { it.lowercase(Locale.ROOT).contains("passport") || it.lowercase(Locale.ROOT).contains("nationality") }

        // Prefer all-caps “NAME SURNAME” style lines.
        val allCaps = lines.firstOrNull { it == it.uppercase(Locale.ROOT) && it.count { ch -> ch == ' ' } in 1..4 }
        if (allCaps != null) return allCaps

        // Otherwise pick the first plausible “words” line.
        val words = lines.firstOrNull { it.matches(Regex("""^[A-Za-z][A-Za-z '\-]+$""")) && it.split(" ").size in 2..5 }
        return words
    }

    private fun findFirst(text: String, regex: Regex, group: Int = 0): String? {
        val m = regex.find(text) ?: return null
        return m.groupValues.getOrNull(group)?.trim()?.takeIf { it.isNotBlank() }
    }

    private fun maskCardNumber(raw: String): String {
        val digits = raw.filter { it.isDigit() }
        if (digits.length < 8) return "****"
        val last4 = digits.takeLast(4)
        return "**** **** **** $last4"
    }
}


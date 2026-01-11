package com.vaultguard.document

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DocumentAutoClassifierTest {
    @Test
    fun classifiesPassportByMrz() {
        val mrz = """
            P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<
            L898902C36UTO7408122F1204159ZE184226B<<<<<10
        """.trimIndent()
        val c = DocumentAutoClassifier.classify(mrz, emptyList())
        assertEquals(DocumentType.PASSPORT, c.type)
        assertTrue(c.confidence >= 0.80)
    }

    @Test
    fun classifiesCreditCardByLuhnPan() {
        // Common test Visa PAN (passes Luhn)
        val card = "CARDHOLDER JOHN DOE\n4111 1111 1111 1111\nVALID THRU 12/30"
        val c = DocumentAutoClassifier.classify(card, emptyList())
        assertEquals(DocumentType.CREDIT_CARD, c.type)
        assertTrue(c.confidence >= 0.70)
    }

    @Test
    fun classifiesTicketByBarcodeAndKeywords() {
        val ticket = "F1 GRAND PRIX\nSEAT A12\nROW 3\nSECTION MAIN"
        val c = DocumentAutoClassifier.classify(ticket, listOf("SOME_QR_DATA_123"))
        assertEquals(DocumentType.TICKET, c.type)
        assertTrue(c.confidence >= 0.70)
    }

    @Test
    fun classifiesIdCardByKeywords() {
        val id = "CARTE DE IDENTITATE\nCNP: 1960101123456\nNAME: ION POPESCU"
        val c = DocumentAutoClassifier.classify(id, emptyList())
        assertEquals(DocumentType.ID_CARD, c.type)
        assertTrue(c.confidence >= 0.40)
    }

    @Test
    fun fallsBackToOtherWhenWeakSignals() {
        val text = "Hello world\nThis is not a document"
        val c = DocumentAutoClassifier.classify(text, emptyList())
        assertEquals(DocumentType.OTHER, c.type)
    }
}


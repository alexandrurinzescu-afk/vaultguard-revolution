package com.vaultguard.document

enum class DocumentType {
    /**
     * Auto classification after capture (SUBPUNCT 2.3.1).
     * The classifier will infer one of the concrete types based on OCR/barcode signals.
     */
    AUTO,
    ID_CARD,
    PASSPORT,
    DRIVER_LICENSE,
    TICKET,
    CREDIT_CARD,
    OTHER,
}


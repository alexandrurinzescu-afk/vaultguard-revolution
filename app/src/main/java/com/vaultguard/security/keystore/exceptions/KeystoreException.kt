package com.vaultguard.security.keystore.exceptions

class KeystoreException(
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)


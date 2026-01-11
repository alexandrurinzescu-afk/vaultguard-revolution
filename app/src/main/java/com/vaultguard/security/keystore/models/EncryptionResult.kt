package com.vaultguard.security.keystore.models

data class EncryptionResult(
    val encryptedData: ByteArray,
    val iv: ByteArray,
)


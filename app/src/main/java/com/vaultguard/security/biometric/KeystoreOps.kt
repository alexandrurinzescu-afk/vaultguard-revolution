package com.vaultguard.security.biometric

import android.content.Context
import com.vaultguard.security.keystore.KeystoreManager
import com.vaultguard.security.keystore.models.EncryptionResult

interface KeystoreOps {
    fun generateKey(alias: String)
    fun encrypt(data: ByteArray, alias: String): EncryptionResult
    fun decrypt(encryptedData: ByteArray, iv: ByteArray, alias: String): ByteArray
    fun deleteKey(alias: String)
    fun keyExists(alias: String): Boolean
}

class AndroidKeystoreOps(context: Context) : KeystoreOps {
    private val km = KeystoreManager(context)

    override fun generateKey(alias: String) = km.generateKey(alias)
    override fun encrypt(data: ByteArray, alias: String): EncryptionResult = km.encrypt(data, alias)
    override fun decrypt(encryptedData: ByteArray, iv: ByteArray, alias: String): ByteArray = km.decrypt(encryptedData, iv, alias)
    override fun deleteKey(alias: String) = km.deleteKey(alias)
    override fun keyExists(alias: String): Boolean = km.keyExists(alias)
}


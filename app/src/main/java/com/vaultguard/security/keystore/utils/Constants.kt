package com.vaultguard.security.keystore.utils

object Constants {
    const val ANDROID_KEYSTORE = "AndroidKeyStore"

    // AES-GCM
    const val AES_MODE = "AES/GCM/NoPadding"
    const val KEY_SIZE_BITS = 256
    const val GCM_TAG_BITS = 128
    const val GCM_IV_BYTES = 12

    // Default alias
    const val DEFAULT_KEY_ALIAS = "vaultguard_aes_key"

    // Auth
    const val AUTH_VALIDITY_SECONDS = 30
}


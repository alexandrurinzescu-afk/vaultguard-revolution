package com.vaultguard.security.network

import java.security.MessageDigest
import java.security.cert.X509Certificate

/**
 * Certificate pinning utilities.
 *
 * This provides a minimal foundation for pinning with HttpURLConnection/HttpsURLConnection.
 *
 * Usage strategy:
 * - When you introduce HTTPS network calls, fetch the server cert's SubjectPublicKeyInfo hash (SPKI)
 * - Store the expected pins (sha256/base64 or hex) and verify the presented cert chain matches.
 *
 * NOTE: This is scaffolding; wiring it into a concrete HTTPS client is a separate step per endpoint.
 */
object CertificatePinning {
    /**
     * Computes SHA-256 of the certificate public key (SPKI) and returns lowercase hex.
     */
    fun spkiSha256Hex(cert: X509Certificate): String {
        val keyBytes = cert.publicKey.encoded
        val digest = MessageDigest.getInstance("SHA-256").digest(keyBytes)
        return digest.joinToString("") { b -> "%02x".format(b) }
    }

    /**
     * Returns true if any certificate in the chain matches any pinned SPKI hash.
     */
    fun chainMatchesPins(chain: Array<X509Certificate>, pinnedSpkiSha256Hex: Set<String>): Boolean {
        val pins = pinnedSpkiSha256Hex.map { it.lowercase() }.toSet()
        return chain.any { cert -> spkiSha256Hex(cert) in pins }
    }
}


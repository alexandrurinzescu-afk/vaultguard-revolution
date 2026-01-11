package com.vaultguard.security

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.vaultguard.security.biometric.BiometricAuthManager
import com.vaultguard.security.biometric.ui.BiometricAuthResult
import com.vaultguard.security.keystore.utils.Constants
import com.vaultguard.security.models.DocumentMetadata
import java.io.BufferedReader
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.security.KeyStore
import java.security.SecureRandom
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * 2.1.3 Secure Storage
 * 2.1.6+ Security upgrades (maximum security phase):
 * - Versioned encrypted file format with per-file key alias (supports rotation).
 * - StrongBox-backed key generation where supported (fallback gracefully).
 * - Key rotation hooks (90 days) with seamless re-encryption.
 *
 * Encrypted file storage for tickets/documents. Uses AES-GCM key backed by Android Keystore.
 *
 * Notes:
 * - Default requires user authentication for key usage (biometric/device gate at OS level).
 * - For automated tests, you can construct with requireUserAuth=false.
 * - Backups are "encrypted backups": we zip the encrypted blobs as-is (no plaintext leaves).
 */
class SecureStorage(
    context: Context,
    private val storageDirName: String = DEFAULT_DIR,
    private val keyAliasBase: String = DEFAULT_KEY_ALIAS_BASE,
    private val requireUserAuth: Boolean = true,
    private val authValiditySeconds: Int = Constants.AUTH_VALIDITY_SECONDS,
) {
    private val appContext = context.applicationContext
    private val secureRandom = SecureRandom()
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun storageDir(): File {
        val dir = File(appContext.filesDir, storageDirName)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun fileFor(name: String): File {
        val safe = sanitizeName(name)
        return File(storageDir(), "$safe.vgenc")
    }

    private fun metaFileFor(name: String): File {
        val safe = sanitizeName(name)
        return File(storageDir(), "$safe.vgmeta")
    }

    fun saveEncryptedDocument(data: ByteArray, fileName: String): Boolean {
        val outFile = fileFor(fileName)
        val alias = currentKeyAlias()
        return runCatching {
            encryptToFile(outFile, alias, data)
            true
        }.getOrDefault(false)
    }

    fun saveDocumentWithMetadata(
        data: ByteArray,
        fileName: String,
        metadata: DocumentMetadata,
    ): Boolean {
        val ok = saveEncryptedDocument(data, fileName)
        if (!ok) return false
        return saveEncryptedMetadata(fileName, metadata)
    }

    fun loadEncryptedDocument(fileName: String): ByteArray? {
        val inFile = fileFor(fileName)
        if (!inFile.exists()) return null
        return runCatching { decryptFromFile(inFile) }.getOrNull()
    }

    fun getDocumentMetadata(fileName: String): DocumentMetadata? {
        val mf = metaFileFor(fileName)
        if (!mf.exists()) return null
        return loadEncryptedMetadata(fileName)
    }

    fun searchByType(type: String): List<String> {
        val normalized = type.trim()
        if (normalized.isEmpty()) return emptyList()
        return listStoredDocuments()
            .filter { name ->
                val meta = runCatching { getDocumentMetadata(name) }.getOrNull()
                meta?.type == normalized
            }
            .sorted()
    }

    /**
     * Migration helper: for any existing encrypted blobs missing metadata, write a minimal metadata record.
     * Returns number of files migrated.
     */
    fun migrateMissingMetadata(defaultType: String = "UNKNOWN"): Int {
        var migrated = 0
        for (name in listStoredDocuments()) {
            val mf = metaFileFor(name)
            if (!mf.exists()) {
                val meta = DocumentMetadata(type = defaultType, displayName = name)
                if (saveEncryptedMetadata(name, meta)) migrated++
            }
        }
        return migrated
    }

    fun deleteStoredDocument(fileName: String): Boolean {
        val f = fileFor(fileName)
        val mf = metaFileFor(fileName)
        val ok1 = (!f.exists() || f.delete())
        val ok2 = (!mf.exists() || mf.delete())
        return ok1 && ok2
    }

    fun listStoredDocuments(): List<String> {
        val dir = storageDir()
        val files = dir.listFiles()?.toList() ?: return emptyList()
        return files
            .filter { it.isFile && it.name.endsWith(".vgenc") }
            .map { it.name.removeSuffix(".vgenc") }
            .sorted()
    }

    /**
     * Export an "encrypted backup" zip: includes encrypted blobs only (no plaintext).
     */
    fun exportEncryptedBackup(destination: File? = null): File {
        val dir = storageDir()
        val out = destination ?: File(appContext.cacheDir, "vaultguard_backup_${System.currentTimeMillis()}.zip")
        if (out.exists()) out.delete()

        ZipOutputStream(BufferedOutputStream(FileOutputStream(out))).use { zos ->
            dir.listFiles()
                ?.filter { it.isFile && (it.name.endsWith(".vgenc") || it.name.endsWith(".vgmeta")) }
                ?.forEach { f ->
                    ZipEntry(f.name).also { entry ->
                        zos.putNextEntry(entry)
                        FileInputStream(f).use { it.copyTo(zos) }
                        zos.closeEntry()
                    }
                }
        }
        return out
    }

    /**
     * Restore an encrypted backup zip. Returns number of files restored.
     */
    fun restoreEncryptedBackup(zipFile: File, overwrite: Boolean = false): Int {
        if (!zipFile.exists()) return 0
        val dir = storageDir()
        var restored = 0

        ZipInputStream(BufferedInputStream(FileInputStream(zipFile))).use { zis ->
            var entry: ZipEntry? = zis.nextEntry
            while (entry != null) {
                val name = entry.name
                val isSupported = name.endsWith(".vgenc") || name.endsWith(".vgmeta")
                if (!entry.isDirectory && isSupported) {
                    val outFile = File(dir, name)
                    if (!outFile.exists() || overwrite) {
                        BufferedOutputStream(FileOutputStream(outFile)).use { bos ->
                            zis.copyTo(bos)
                            bos.flush()
                        }
                        restored++
                    }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
        return restored
    }

    /**
     * Optional biometric-gated wrappers (non-blocking callbacks).
     * These reuse BiometricAuthManager session gating.
     */
    fun saveEncryptedDocumentGated(
        auth: BiometricAuthManager,
        activity: androidx.fragment.app.FragmentActivity,
        data: ByteArray,
        fileName: String,
        handler: (BiometricAuthResult, Boolean) -> Unit,
    ) {
        auth.encryptWithBiometricGate(activity, data, currentKeyAlias()) { result, _, _ ->
            if (result is BiometricAuthResult.Success) {
                // We still encrypt the file ourselves; the gate ensures recent auth.
                val ok = runCatching { saveEncryptedDocument(data, fileName) }.getOrDefault(false)
                handler(result, ok)
            } else {
                handler(result, false)
            }
        }
    }

    fun loadEncryptedDocumentGated(
        auth: BiometricAuthManager,
        activity: androidx.fragment.app.FragmentActivity,
        fileName: String,
        handler: (BiometricAuthResult, ByteArray?) -> Unit,
    ) {
        auth.authenticate(activity, reason = "Load secure document") { result ->
            if (result is BiometricAuthResult.Success) {
                handler(result, runCatching { loadEncryptedDocument(fileName) }.getOrNull())
            } else {
                handler(result, null)
            }
        }
    }

    /**
     * Returns the currently active key alias. New writes should use this alias.
     *
     * Rotation policy: rotate every [ROTATION_DAYS] (checked by [rotateKeysIfNeeded]).
     */
    fun currentKeyAlias(nowMillis: Long = System.currentTimeMillis()): String {
        val explicit = prefs.getString(KEY_CURRENT_ALIAS, null)
        if (!explicit.isNullOrBlank()) return explicit
        // First run: initialize a stable alias and persist it.
        val alias = "${keyAliasBase}_v1"
        prefs.edit().putString(KEY_CURRENT_ALIAS, alias).putLong(KEY_LAST_ROTATED_AT_MS, nowMillis).apply()
        return alias
    }

    /**
     * Rotate keys (90 days) and seamlessly re-encrypt all stored blobs + metadata.
     *
     * Returns number of files re-encrypted (both .vgenc and .vgmeta count).
     */
    fun rotateKeysIfNeeded(nowMillis: Long = System.currentTimeMillis()): Int {
        val last = prefs.getLong(KEY_LAST_ROTATED_AT_MS, 0L)
        val due = last == 0L || nowMillis - last >= TimeUnit.DAYS.toMillis(ROTATION_DAYS)
        if (!due) return 0

        val newAlias = "${keyAliasBase}_${nowMillis}"
        // Ensure key exists before migration
        getOrCreateAesKey(newAlias)
        val migrated = reencryptAllToAlias(newAlias)
        prefs.edit().putString(KEY_CURRENT_ALIAS, newAlias).putLong(KEY_LAST_ROTATED_AT_MS, nowMillis).apply()
        return migrated
    }

    /**
     * Wipe all encrypted blobs and metadata and (optionally) delete known keystore keys.
     *
     * Use this for "self-destruct" flows.
     */
    fun wipeAllStoredData(deleteKeys: Boolean = true): Boolean {
        val dir = storageDir()
        val okFiles = dir.listFiles()?.all { it.delete() } ?: true

        if (deleteKeys) {
            runCatching {
                val ks = KeyStore.getInstance(Constants.ANDROID_KEYSTORE).apply { load(null) }
                val aliases = ks.aliases()
                while (aliases.hasMoreElements()) {
                    val alias = aliases.nextElement()
                    if (alias.startsWith(keyAliasBase)) {
                        ks.deleteEntry(alias)
                    }
                }
            }
        }

        // Clear our rotation prefs too.
        prefs.edit().clear().apply()
        return okFiles
    }

    private fun getOrCreateAesKey(alias: String): SecretKey {
        val ks = KeyStore.getInstance(Constants.ANDROID_KEYSTORE).apply { load(null) }
        val existing = ks.getKey(alias, null) as? SecretKey
        if (existing != null) return existing

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, Constants.ANDROID_KEYSTORE)
        fun buildSpec(strongBox: Boolean): KeyGenParameterSpec {
            val builder = KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(Constants.KEY_SIZE_BITS)
                .setRandomizedEncryptionRequired(true)
                .setUserAuthenticationRequired(requireUserAuth)

            if (requireUserAuth) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    builder.setUserAuthenticationParameters(
                        authValiditySeconds,
                        KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    builder.setUserAuthenticationValidityDurationSeconds(authValiditySeconds)
                }
            }

            if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // StrongBox may not exist on all devices; if absent, init() can throw.
                builder.setIsStrongBoxBacked(true)
            }
            return builder.build()
        }

        // Try StrongBox first (when possible), then fallback to regular TEE-backed keystore.
        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                keyGenerator.init(buildSpec(strongBox = true))
            } else {
                keyGenerator.init(buildSpec(strongBox = false))
            }
            keyGenerator.generateKey()
        }.recoverCatching {
            keyGenerator.init(buildSpec(strongBox = false))
            keyGenerator.generateKey()
        }.getOrThrow()
    }

    private fun saveEncryptedMetadata(fileName: String, metadata: DocumentMetadata): Boolean {
        val outFile = metaFileFor(fileName)
        val alias = currentKeyAlias()
        val plaintext = metadata.toJsonString().toByteArray(Charsets.UTF_8)
        return runCatching {
            encryptToFile(outFile, alias, plaintext)
            true
        }.getOrDefault(false)
    }

    private fun loadEncryptedMetadata(fileName: String): DocumentMetadata? {
        val inFile = metaFileFor(fileName)
        if (!inFile.exists()) return null
        val json = runCatching { decryptFromFile(inFile).toString(Charsets.UTF_8) }.getOrNull() ?: return null
        return runCatching { DocumentMetadata.fromJsonString(json) }.getOrNull()
    }

    private fun encryptToFile(outFile: File, alias: String, plaintext: ByteArray) {
        val key = getOrCreateAesKey(alias)
        val cipher = Cipher.getInstance(Constants.AES_MODE)

        val iv = ByteArray(Constants.GCM_IV_BYTES)
        secureRandom.nextBytes(iv)
        val spec = GCMParameterSpec(Constants.GCM_TAG_BITS, iv)
        cipher.init(Cipher.ENCRYPT_MODE, key, spec)
        val ciphertext = cipher.doFinal(plaintext)

        // File format v2:
        // [int MAGIC][int aliasLen][alias utf8][int ivLen][iv][int ctLen][ct]
        DataOutputStream(BufferedOutputStream(FileOutputStream(outFile))).use { dos ->
            val aliasBytes = alias.toByteArray(Charsets.UTF_8)
            dos.writeInt(MAGIC_VGS2)
            dos.writeInt(aliasBytes.size)
            dos.write(aliasBytes)
            dos.writeInt(iv.size)
            dos.write(iv)
            dos.writeInt(ciphertext.size)
            dos.write(ciphertext)
            dos.flush()
        }
    }

    private fun decryptFromFile(inFile: File): ByteArray {
        val parsed = parseEncryptedFile(inFile)
        val alias = parsed.keyAlias ?: currentKeyAlias()
        val key = getOrCreateAesKey(alias)
        val cipher = Cipher.getInstance(Constants.AES_MODE)
        val spec = GCMParameterSpec(Constants.GCM_TAG_BITS, parsed.iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher.doFinal(parsed.ciphertext)
    }

    private data class ParsedEncryptedFile(
        val keyAlias: String?,
        val iv: ByteArray,
        val ciphertext: ByteArray,
    )

    private fun parseEncryptedFile(file: File): ParsedEncryptedFile {
        DataInputStream(BufferedInputStream(FileInputStream(file))).use { dis ->
            val first = dis.readInt()
            return if (first == MAGIC_VGS2) {
                val aliasLen = dis.readInt()
                require(aliasLen in 1..256) { "Invalid aliasLen=$aliasLen" }
                val aliasBytes = ByteArray(aliasLen)
                dis.readFully(aliasBytes)
                val alias = aliasBytes.toString(Charsets.UTF_8)

                val ivLen = dis.readInt()
                require(ivLen in 1..64) { "Invalid ivLen=$ivLen" }
                val iv = ByteArray(ivLen)
                dis.readFully(iv)

                val ctLen = dis.readInt()
                require(ctLen in 1..100_000_000) { "Invalid ctLen=$ctLen" }
                val ct = ByteArray(ctLen)
                dis.readFully(ct)
                ParsedEncryptedFile(keyAlias = alias, iv = iv, ciphertext = ct)
            } else {
                // Backward compatible (v1):
                // [int ivLen][iv][int ctLen][ct]
                val ivLen = first
                if (ivLen <= 0 || ivLen > 64) throw IllegalStateException("Invalid v1 ivLen=$ivLen")
                val iv = ByteArray(ivLen)
                dis.readFully(iv)
                val ctLen = dis.readInt()
                if (ctLen <= 0 || ctLen > 100_000_000) throw IllegalStateException("Invalid v1 ctLen=$ctLen")
                val ct = ByteArray(ctLen)
                dis.readFully(ct)
                ParsedEncryptedFile(keyAlias = "${keyAliasBase}_v1", iv = iv, ciphertext = ct)
            }
        }
    }

    private fun reencryptAllToAlias(newAlias: String): Int {
        var migrated = 0
        val dir = storageDir()
        val files = dir.listFiles()?.toList() ?: return 0
        for (f in files) {
            if (!f.isFile) continue
            if (!(f.name.endsWith(".vgenc") || f.name.endsWith(".vgmeta"))) continue
            val plaintext = runCatching { decryptFromFile(f) }.getOrNull() ?: continue
            runCatching {
                encryptToFile(f, newAlias, plaintext)
                migrated++
            }
        }
        return migrated
    }

    private fun sanitizeName(name: String): String {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return "unnamed"
        return trimmed.replace(Regex("[^a-zA-Z0-9._-]"), "_")
    }

    private companion object {
        private const val DEFAULT_DIR = "vaultguard_secure_storage"
        private const val DEFAULT_KEY_ALIAS_BASE = "vaultguard_secure_storage_key"

        private const val PREFS_NAME = "vaultguard_secure_storage_prefs"
        private const val KEY_CURRENT_ALIAS = "current_alias"
        private const val KEY_LAST_ROTATED_AT_MS = "last_rotated_at_ms"

        private const val ROTATION_DAYS = 90L

        // 'VGS2' (VaultGuard Storage v2)
        private const val MAGIC_VGS2 = 0x56475332
    }
}


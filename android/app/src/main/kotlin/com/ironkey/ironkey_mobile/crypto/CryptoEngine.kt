package com.ironkey.ironkey_mobile.crypto

import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Arrays
import java.util.Base64

/**
 * Motor criptográfico compatível com o IronKey CryptoManager v2/v3 e Contrato de Sync Fase 0.
 */
class CryptoEngine {

    companion object {
        const val FORMAT_VERSION = 2
        const val KEY_SIZE_BYTES = 32
        val RECORD_AAD = "ironkeypy.record.v2".toByteArray(StandardCharsets.UTF_8)
        val SYNC_KEY_PURPOSE = "IronKeyPy/sync-key/v1".toByteArray(StandardCharsets.UTF_8)
        val MANIFEST_KEY_PURPOSE = "IronKeyPy/sync-manifest/v1".toByteArray(StandardCharsets.UTF_8)
        val VERIFIER_PLAINTEXT = "IronKeyPy/vault-verifier/v2".toByteArray(StandardCharsets.UTF_8)
        val VERIFIER_AAD = "verifier".toByteArray(StandardCharsets.UTF_8)
    }

    private var activeDek: ByteArray? = null
    var vaultId: String? = null
        private set
    var headerJson: JSONObject? = null
        private set

    val isUnlocked: Boolean
        get() = activeDek != null

    fun unlock(masterPassword: String, configJsonStr: String): Boolean {
        val config = JSONObject(configJsonStr)
        val formatVersion = config.optInt("format_version", 1)
        if (formatVersion != FORMAT_VERSION) {
            throw IllegalArgumentException("Versão de formato não suportada: $formatVersion")
        }

        val kdf = config.getJSONObject("kdf")
        val algorithm = kdf.getString("algorithm")
        if (algorithm != "argon2id") {
            throw IllegalArgumentException("Algoritmo KDF não suportado: $algorithm")
        }

        val salt = kdf.getString("salt")
        val timeCost = kdf.getInt("time_cost")
        val memoryCost = kdf.getInt("memory_cost")
        val parallelism = kdf.getInt("parallelism")

        val kek = Argon2Kdf.deriveKey(
            password = masterPassword,
            saltBase64 = salt,
            timeCost = timeCost,
            memoryCostKiB = memoryCost,
            parallelism = parallelism,
            keyLengthBytes = KEY_SIZE_BYTES
        )

        val aad = headerAad(config)
        val wrappedDek = config.getString("wrapped_dek")
        val verifier = config.getString("verifier")

        val dek: ByteArray
        try {
            dek = AesGcmCipher.decryptEmbedded(wrappedDek, kek, aad)
        } catch (e: Exception) {
            Arrays.fill(kek, 0.toByte())
            return false
        }
        Arrays.fill(kek, 0.toByte())

        if (!checkVerifier(dek, verifier)) {
            Arrays.fill(dek, 0.toByte())
            return false
        }

        lock()
        this.activeDek = dek
        this.vaultId = config.getString("vault_id")
        this.headerJson = config
        return true
    }

    fun lock() {
        activeDek?.let {
            Arrays.fill(it, 0.toByte())
        }
        activeDek = null
        vaultId = null
        headerJson = null
    }

    fun encryptRecord(plaintext: String): String {
        val dek = activeDek ?: throw IllegalStateException("Cofre trancado.")
        return AesGcmCipher.encryptEmbedded(plaintext.toByteArray(StandardCharsets.UTF_8), dek, RECORD_AAD)
    }

    fun decryptRecord(ciphertextBase64: String): String {
        val dek = activeDek ?: throw IllegalStateException("Cofre trancado.")
        val bytes = AesGcmCipher.decryptEmbedded(ciphertextBase64, dek, RECORD_AAD)
        return String(bytes, StandardCharsets.UTF_8)
    }

    fun deriveSubkey(purpose: ByteArray, outputLength: Int = KEY_SIZE_BYTES): ByteArray {
        val dek = activeDek ?: throw IllegalStateException("Cofre trancado.")
        val vId = vaultId ?: throw IllegalStateException("Vault ID não disponível.")
        // No Python, self.vault_id_bytes() é o decode Base64 do vault_id (8 bytes de salt)
        val salt = try {
            Base64.getDecoder().decode(vId)
        } catch (e: Exception) {
            vId.toByteArray(StandardCharsets.UTF_8)
        }
        return Hkdf.deriveSubkey(dek, salt, purpose, outputLength)
    }

    fun getSyncKey(): ByteArray {
        return deriveSubkey(SYNC_KEY_PURPOSE)
    }

    fun getManifestKey(): ByteArray {
        return deriveSubkey(MANIFEST_KEY_PURPOSE)
    }

    private fun checkVerifier(dek: ByteArray, verifierBase64: String): Boolean {
        return try {
            val decryptedVerifier = AesGcmCipher.decryptEmbedded(verifierBase64, dek, VERIFIER_AAD)
            MessageDigest.isEqual(decryptedVerifier, VERIFIER_PLAINTEXT)
        } catch (e: Exception) {
            false
        }
    }

    private fun headerAad(header: JSONObject): ByteArray {
        val meta = JSONObject()
        meta.put("format_version", header.getInt("format_version"))
        meta.put("kdf", header.getJSONObject("kdf"))
        meta.put("vault_id", header.getString("vault_id"))
        return CanonicalJson.canonicalBytes(meta)
    }
}

package com.ironkey.ironkey_mobile.crypto

import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Cifragem e decifragem AES-256-GCM com suporte a nonce embutido ou explícito.
 */
object AesGcmCipher {

    const val NONCE_SIZE_BYTES = 12
    private const val TAG_SIZE_BITS = 128
    private val random = SecureRandom()

    /**
     * Cifra e retorna Base64(nonce [12 bytes] + ciphertext + tag [16 bytes]).
     * Usado para wrapped_dek, verifier e registros do banco.
     */
    fun encryptEmbedded(
        plaintext: ByteArray,
        key: ByteArray,
        aad: ByteArray? = null
    ): String {
        val nonce = ByteArray(NONCE_SIZE_BYTES)
        random.nextBytes(nonce)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val keySpec = SecretKeySpec(key, "AES")
        val gcmSpec = GCMParameterSpec(TAG_SIZE_BITS, nonce)

        cipher.init(Cipher.ENCRYPT_MODE, keySpec, gcmSpec)
        if (aad != null && aad.isNotEmpty()) {
            cipher.updateAAD(aad)
        }

        val ciphertextWithTag = cipher.doFinal(plaintext)
        val combined = ByteArray(nonce.size + ciphertextWithTag.size)
        System.arraycopy(nonce, 0, combined, 0, nonce.size)
        System.arraycopy(ciphertextWithTag, 0, combined, nonce.size, ciphertextWithTag.size)

        return Base64.getEncoder().encodeToString(combined)
    }

    /**
     * Decifra a partir de Base64(nonce [12 bytes] + ciphertext + tag [16 bytes]).
     */
    fun decryptEmbedded(
        encryptedBase64: String,
        key: ByteArray,
        aad: ByteArray? = null
    ): ByteArray {
        val combined = Base64.getDecoder().decode(encryptedBase64)
        if (combined.size < NONCE_SIZE_BYTES + (TAG_SIZE_BITS / 8)) {
            throw IllegalArgumentException("Payload AES-GCM corrompido ou truncado.")
        }

        val nonce = ByteArray(NONCE_SIZE_BYTES)
        val ciphertextWithTag = ByteArray(combined.size - NONCE_SIZE_BYTES)

        System.arraycopy(combined, 0, nonce, 0, NONCE_SIZE_BYTES)
        System.arraycopy(combined, NONCE_SIZE_BYTES, ciphertextWithTag, 0, ciphertextWithTag.size)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val keySpec = SecretKeySpec(key, "AES")
        val gcmSpec = GCMParameterSpec(TAG_SIZE_BITS, nonce)

        cipher.init(Cipher.DECRYPT_MODE, keySpec, gcmSpec)
        if (aad != null && aad.isNotEmpty()) {
            cipher.updateAAD(aad)
        }

        return cipher.doFinal(ciphertextWithTag)
    }

    /**
     * Decifra quando o nonce e o ciphertext são passados separadamente (usado no .ikenr e no ironkeypy-sync.ikbak).
     */
    fun decryptWithNonce(
        ciphertextWithTagBase64: String,
        nonceBase64: String,
        key: ByteArray,
        aad: ByteArray? = null
    ): ByteArray {
        val nonce = Base64.getDecoder().decode(nonceBase64)
        val ciphertextWithTag = Base64.getDecoder().decode(ciphertextWithTagBase64)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val keySpec = SecretKeySpec(key, "AES")
        val gcmSpec = GCMParameterSpec(TAG_SIZE_BITS, nonce)

        cipher.init(Cipher.DECRYPT_MODE, keySpec, gcmSpec)
        if (aad != null && aad.isNotEmpty()) {
            cipher.updateAAD(aad)
        }

        return cipher.doFinal(ciphertextWithTag)
    }

    /**
     * Cifra com nonce gerado e retorna Pair(ciphertextWithTagBase64, nonceBase64).
     */
    fun encryptWithSeparateNonce(
        plaintext: ByteArray,
        key: ByteArray,
        aad: ByteArray? = null
    ): Pair<String, String> {
        val nonce = ByteArray(NONCE_SIZE_BYTES)
        random.nextBytes(nonce)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val keySpec = SecretKeySpec(key, "AES")
        val gcmSpec = GCMParameterSpec(TAG_SIZE_BITS, nonce)

        cipher.init(Cipher.ENCRYPT_MODE, keySpec, gcmSpec)
        if (aad != null && aad.isNotEmpty()) {
            cipher.updateAAD(aad)
        }

        val ciphertextWithTag = cipher.doFinal(plaintext)
        return Pair(
            Base64.getEncoder().encodeToString(ciphertextWithTag),
            Base64.getEncoder().encodeToString(nonce)
        )
    }
}

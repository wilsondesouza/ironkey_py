package com.ironkey.ironkey_mobile.crypto

import org.bouncycastle.crypto.generators.Argon2BytesGenerator
import org.bouncycastle.crypto.params.Argon2Parameters
import java.nio.charset.StandardCharsets
import java.util.Base64

/**
 * Derivação de chaves via Argon2id compatível com o CryptoManager Python do IronKey.
 */
object Argon2Kdf {

    fun deriveKey(
        password: String,
        saltBase64: String,
        timeCost: Int,
        memoryCostKiB: Int,
        parallelism: Int,
        keyLengthBytes: Int = 32
    ): ByteArray {
        val salt = Base64.getDecoder().decode(saltBase64)
        val passwordBytes = password.toByteArray(StandardCharsets.UTF_8)

        val params = Argon2Parameters.Builder(Argon2Parameters.ARGON2_id)
            .withVersion(Argon2Parameters.ARGON2_VERSION_13)
            .withIterations(timeCost)
            .withMemoryAsKB(memoryCostKiB)
            .withParallelism(parallelism)
            .withSalt(salt)
            .build()

        val generator = Argon2BytesGenerator()
        generator.init(params)

        val result = ByteArray(keyLengthBytes)
        generator.generateBytes(passwordBytes, result, 0, result.size)
        return result
    }
}

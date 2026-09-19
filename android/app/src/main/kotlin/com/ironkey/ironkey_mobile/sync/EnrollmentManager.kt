package com.ironkey.ironkey_mobile.sync

import com.ironkey.ironkey_mobile.crypto.AesGcmCipher
import com.ironkey.ironkey_mobile.crypto.Argon2Kdf
import com.ironkey.ironkey_mobile.crypto.CryptoEngine
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.nio.charset.StandardCharsets
import java.util.Arrays
import java.util.zip.GZIPInputStream

/**
 * Importação e validação de arquivos de entrada de dispositivo (.ikenr).
 */
object EnrollmentManager {

    private const val ENROLL_MAGIC = "IronKeyPy-Enroll"
    private const val ENROLL_VERSION = 1
    private val ENROLL_AAD = "ironkeypy.enroll.v1".toByteArray(StandardCharsets.UTF_8)

    data class EnrollmentData(
        val headerJsonStr: String,
        val createdAt: String,
        val sourceDevice: String
    )

    fun readEnrollment(ikenrJsonStr: String, masterPassword: String): EnrollmentData {
        val root = JSONObject(ikenrJsonStr)
        val magic = root.optString("magic")
        if (magic != ENROLL_MAGIC) {
            throw IllegalArgumentException("Arquivo de entrada inválido (magic incompatível).")
        }

        val version = root.optInt("version", 0)
        if (version > ENROLL_VERSION) {
            throw IllegalArgumentException("Versão de pareamento $version superior à suportada ($ENROLL_VERSION). Atualize o app.")
        }

        val kdf = root.getJSONObject("kdf")
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
            keyLengthBytes = 32
        )

        val dataBase64 = root.getString("data")
        val nonceBase64 = root.getString("nonce")

        val decryptedGzip: ByteArray
        try {
            decryptedGzip = AesGcmCipher.decryptWithNonce(dataBase64, nonceBase64, kek, ENROLL_AAD)
        } catch (e: Exception) {
            Arrays.fill(kek, 0.toByte())
            throw IllegalArgumentException("Senha mestre incorreta ou arquivo corrompido.")
        }
        Arrays.fill(kek, 0.toByte())

        // Descomprime GZIP
        val uncompressed = GZIPInputStream(ByteArrayInputStream(decryptedGzip)).readBytes()
        val payloadStr = String(uncompressed, StandardCharsets.UTF_8)
        val payload = JSONObject(payloadStr)

        val header = payload.getJSONObject("header")
        val createdAt = payload.optString("created_at", "")
        val sourceDevice = payload.optString("source_device", "")

        // Valida se a DEK contida no cabeçalho realmente abre com a senha mestre
        val testEngine = CryptoEngine()
        val unlocked = testEngine.unlock(masterPassword, header.toString())
        if (!unlocked) {
            throw IllegalArgumentException("A senha mestre não corresponde a este cofre.")
        }
        testEngine.lock()

        return EnrollmentData(
            headerJsonStr = header.toString(),
            createdAt = createdAt,
            sourceDevice = sourceDevice
        )
    }
}

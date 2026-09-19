package com.ironkey.ironkey_mobile.sync

import com.ironkey.ironkey_mobile.crypto.AesGcmCipher
import com.ironkey.ironkey_mobile.crypto.CanonicalJson
import com.ironkey.ironkey_mobile.crypto.CryptoEngine
import com.ironkey.ironkey_mobile.crypto.Hkdf
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Base64
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream

/**
 * Operações normativas do documento de sincronização (leitura, escrita e validação de manifesto).
 * Totalmente compatível com a especificação normativa da Fase 0 (CONTRATO-DE-SINCRONIZACAO.md).
 */
class SyncEngineNative(private val crypto: CryptoEngine) {

    companion object {
        const val SYNC_MAGIC = "IronKeyPy-Sync"
        const val SYNC_DOC_VERSION = 1
        const val MANIFEST_MAGIC = "IronKeyPy-Sync-Manifest"
        const val MANIFEST_VERSION = 1

        /**
         * Converte recursivamente estruturas org.json (JSONObject, JSONArray, JSONObject.NULL)
         * para tipos primitivos nativos do Kotlin/Java compatíveis com o Flutter MethodChannel.
         */
        fun jsonToNative(value: Any?): Any? {
            return when (value) {
                null, JSONObject.NULL -> null
                is JSONObject -> {
                    val map = mutableMapOf<String, Any?>()
                    val keys = value.keys()
                    while (keys.hasNext()) {
                        val k = keys.next()
                        map[k] = jsonToNative(value.get(k))
                    }
                    map
                }
                is JSONArray -> {
                    val list = mutableListOf<Any?>()
                    for (i in 0 until value.length()) {
                        list.add(jsonToNative(value.get(i)))
                    }
                    list
                }
                else -> value
            }
        }
    }

    data class DecryptedSyncDoc(
        val generation: Long,
        val vaultId: String,
        val entries: List<Map<String, Any?>>,
        val devices: List<Map<String, Any?>>,
        val purgedUids: List<String>
    )

    fun readSyncBlob(blobBytes: ByteArray): DecryptedSyncDoc {
        val syncKey = crypto.getSyncKey()
        val jsonString = String(blobBytes, StandardCharsets.UTF_8)
        val root = JSONObject(jsonString)

        val magic = root.optString("magic")
        if (magic != SYNC_MAGIC) {
            throw IllegalArgumentException("Magic inválido: '$magic' (esperado '$SYNC_MAGIC').")
        }

        val docVersion = root.optInt("version", 0)
        if (docVersion > SYNC_DOC_VERSION) {
            throw IllegalArgumentException("Versão do arquivo de sync ($docVersion) não suportada.")
        }

        val remoteVaultId = root.optString("vault_id")
        if (remoteVaultId.isNotEmpty() && remoteVaultId != crypto.vaultId) {
            throw IllegalArgumentException("Cofre divergente (nuvem: '$remoteVaultId', celular: '${crypto.vaultId}'). Re-importe o .ikenr.")
        }

        val dataBase64 = root.getString("data")
        val nonceBase64 = root.getString("nonce")

        val aad = payloadAad(root)
        val decryptedGzip: ByteArray
        try {
            decryptedGzip = AesGcmCipher.decryptWithNonce(dataBase64, nonceBase64, syncKey, aad)
        } catch (e: Exception) {
            throw IllegalStateException("Falha de autenticação AES-GCM da chave do cofre: ${e.message}")
        }

        val uncompressed = GZIPInputStream(ByteArrayInputStream(decryptedGzip)).readBytes()
        val payload = JSONObject(String(uncompressed, StandardCharsets.UTF_8))

        val generation = root.optLong("generation", payload.optLong("generation", 0L))
        val entriesJson = payload.optJSONArray("entries") ?: JSONArray()
        
        val rawConverted = jsonToNative(entriesJson) as? List<*> ?: emptyList<Any?>()
        val entriesList = mutableListOf<Map<String, Any?>>()
        for (item in rawConverted) {
            if (item is Map<*, *>) {
                @Suppress("UNCHECKED_CAST")
                entriesList.add(item as Map<String, Any?>)
            }
        }

        val purgedJson = payload.optJSONArray("purged_uids") ?: JSONArray()
        val purgedList = mutableListOf<String>()
        for (i in 0 until purgedJson.length()) {
            purgedList.add(purgedJson.getString(i))
        }

        return DecryptedSyncDoc(
            generation = generation,
            vaultId = remoteVaultId,
            entries = entriesList,
            devices = emptyList(),
            purgedUids = purgedList
        )
    }

    fun verifyManifestDetailed(manifestJsonStr: String, blobBytes: ByteArray): Map<String, Any?> {
        if (manifestJsonStr.isBlank()) {
            return mapOf(
                "valid" to false,
                "reason" to "Manifesto vazio ou arquivo ironkeypy-sync.manifest.json ausente na pasta."
            )
        }

        try {
            val manifest = JSONObject(manifestJsonStr)

            val magic = manifest.optString("magic")
            if (magic != MANIFEST_MAGIC && magic != "IronKeyPy-Manifest") {
                return mapOf(
                    "valid" to false,
                    "reason" to "Magic do manifesto inválido: '$magic' (esperado: $MANIFEST_MAGIC)"
                )
            }

            val docVersion = manifest.optInt("version", 1)
            if (docVersion > MANIFEST_VERSION) {
                return mapOf(
                    "valid" to false,
                    "reason" to "Versão do manifesto ($docVersion) superior à suportada ($MANIFEST_VERSION)."
                )
            }

            val manifestVaultId = manifest.optString("vault_id")
            if (manifestVaultId.isNotEmpty() && manifestVaultId != crypto.vaultId) {
                return mapOf(
                    "valid" to false,
                    "reason" to "Cofre divergente (manifesto: '$manifestVaultId', local: '${crypto.vaultId}'). Re-importe o arquivo de entrada .ikenr."
                )
            }

            val expectedSize = manifest.optLong("payload_bytes", manifest.optLong("data_bytes", -1L))
            if (expectedSize != -1L && blobBytes.size.toLong() != expectedSize) {
                return mapOf(
                    "valid" to false,
                    "reason" to "Download incompleto pela nuvem: lidos ${blobBytes.size} bytes, manifesto indica $expectedSize bytes."
                )
            }

            val expectedSha = manifest.optString("payload_sha256", manifest.optString("data_sha256", ""))
            val actualSha = Hkdf.bytesToHex(Hkdf.sha256(blobBytes))
            if (expectedSha.isNotEmpty() && !actualSha.equals(expectedSha, ignoreCase = true)) {
                return mapOf(
                    "valid" to false,
                    "reason" to "Hash SHA-256 do arquivo difere do manifesto (arquivo de sync incompleto ou transferido parcialmente)."
                )
            }

            val expectedMac = manifest.optString("mac")
            if (expectedMac.isEmpty()) {
                return mapOf(
                    "valid" to false,
                    "reason" to "Campo de assinatura 'mac' ausente no manifesto."
                )
            }

            // Canonical JSON de todos os campos EXCETO "mac"
            val body = JSONObject()
            val keys = manifest.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                if (k != "mac") {
                    body.put(k, manifest.get(k))
                }
            }

            val manifestKey = crypto.getManifestKey()
            val canonicalString = CanonicalJson.canonicalize(body)
            val canonicalBytes = canonicalString.toByteArray(StandardCharsets.UTF_8)
            val hmacBytes = Hkdf.hmacSha256(manifestKey, canonicalBytes)
            val actualMacBase64 = Base64.getEncoder().encodeToString(hmacBytes)

            if (actualMacBase64 != expectedMac) {
                return mapOf(
                    "valid" to false,
                    "reason" to "Assinatura MAC divergente (chave do cofre não confere ou manifesto alterado)."
                )
            }

            return mapOf("valid" to true)
        } catch (e: Throwable) {
            return mapOf(
                "valid" to false,
                "reason" to "Exceção ao validar manifesto: ${e.message}"
            )
        }
    }

    fun buildSyncPayload(
        generation: Long,
        entries: List<Map<String, Any?>>,
        deviceId: String,
        purgedUids: List<String>
    ): Pair<ByteArray, String> {
        val syncKey = crypto.getSyncKey()
        val manifestKey = crypto.getManifestKey()
        val vId = crypto.vaultId!!
        val nowIso = getUtcIsoString()

        // 1. Conteúdo descompactado interno (schema 3)
        val payload = JSONObject()
        payload.put("schema", 3)
        payload.put("created_at", nowIso)
        payload.put("vault_id", vId)
        payload.put("generation", generation)
        payload.put("updated_at", nowIso)
        payload.put("updated_by", deviceId)

        val purgeObj = JSONObject()
        purgeObj.put("tombstone_max_age_days", 90)
        payload.put("purge", purgeObj)

        val devicesArray = JSONArray()
        val devObj = JSONObject()
        devObj.put("device_id", deviceId)
        devObj.put("label", "Android")
        devObj.put("last_seen", nowIso)
        devicesArray.put(devObj)
        payload.put("devices", devicesArray)

        val entriesArray = JSONArray()
        for (e in entries) {
            entriesArray.put(JSONObject(e))
        }
        payload.put("entries", entriesArray)

        val purgedArray = JSONArray()
        for (uid in purgedUids) {
            purgedArray.put(uid)
        }
        payload.put("purged_uids", purgedArray)

        // Comprime em GZIP
        val canonicalBytes = CanonicalJson.canonicalBytes(payload)
        val byteOut = ByteArrayOutputStream()
        GZIPOutputStream(byteOut).use { gzip ->
            gzip.write(canonicalBytes)
        }
        val gzipped = byteOut.toByteArray()

        // 2. Envelope externo .ikbak
        val outerDoc = JSONObject()
        outerDoc.put("magic", SYNC_MAGIC)
        outerDoc.put("version", SYNC_DOC_VERSION)
        outerDoc.put("vault_id", vId)
        outerDoc.put("generation", generation)
        outerDoc.put("updated_at", nowIso)
        outerDoc.put("updated_by", deviceId)
        outerDoc.put("app", "IronKey Mobile")

        val aad = payloadAad(outerDoc)
        val (ciphertextBase64, nonceBase64) = AesGcmCipher.encryptWithSeparateNonce(gzipped, syncKey, aad)

        outerDoc.put("nonce", nonceBase64)
        outerDoc.put("data", ciphertextBase64)

        val blobBytes = outerDoc.toString(2).toByteArray(StandardCharsets.UTF_8)
        val dataSha = Hkdf.bytesToHex(Hkdf.sha256(blobBytes))

        // 3. Manifesto autenticado em conformidade com o contrato
        val manifest = JSONObject()
        manifest.put("magic", MANIFEST_MAGIC)
        manifest.put("version", MANIFEST_VERSION)
        manifest.put("vault_id", vId)
        manifest.put("generation", generation)
        manifest.put("payload_file", "ironkeypy-sync.ikbak")
        manifest.put("payload_bytes", blobBytes.size.toLong())
        manifest.put("payload_sha256", dataSha)
        manifest.put("updated_at", nowIso)
        manifest.put("updated_by", deviceId)
        manifest.put("app", "IronKey Mobile")

        val manifestCanonical = CanonicalJson.canonicalBytes(manifest)
        val hmacBytes = Hkdf.hmacSha256(manifestKey, manifestCanonical)
        val macBase64 = Base64.getEncoder().encodeToString(hmacBytes)

        manifest.put("mac", macBase64)
        return Pair(blobBytes, manifest.toString(2))
    }

    private fun payloadAad(header: JSONObject): ByteArray {
        val meta = JSONObject()
        meta.put("magic", header.optString("magic"))
        meta.put("version", header.optInt("version"))
        meta.put("vault_id", header.optString("vault_id"))
        meta.put("generation", header.optLong("generation"))
        meta.put("updated_by", header.optString("updated_by"))
        return CanonicalJson.canonicalBytes(meta)
    }

    private fun getUtcIsoString(): String {
        val df = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        df.timeZone = TimeZone.getTimeZone("UTC")
        return df.format(Date())
    }
}

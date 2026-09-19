package com.ironkey.ironkey_mobile.crypto

import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Derivação de subchaves por HKDF-SHA256 (RFC 5869) e HMAC-SHA256 padrão Java.
 */
object Hkdf {

    fun deriveSubkey(
        ikm: ByteArray,
        salt: ByteArray,
        info: ByteArray,
        outputLengthBytes: Int = 32
    ): ByteArray {
        // RFC 5869 Step 1: Extract (PRK = HMAC-Hash(salt, IKM))
        val extractMac = Mac.getInstance("HmacSHA256")
        extractMac.init(SecretKeySpec(salt, "HmacSHA256"))
        val prk = extractMac.doFinal(ikm)

        // RFC 5869 Step 2: Expand (OKM = HMAC-Hash(PRK, info || 0x01))
        val expandMac = Mac.getInstance("HmacSHA256")
        expandMac.init(SecretKeySpec(prk, "HmacSHA256"))

        val okm = ByteArray(outputLengthBytes)
        var t = ByteArray(0)
        var pos = 0
        var counter: Byte = 1

        while (pos < outputLengthBytes) {
            expandMac.update(t)
            expandMac.update(info)
            expandMac.update(counter)
            t = expandMac.doFinal()

            val toCopy = Math.min(t.size, outputLengthBytes - pos)
            System.arraycopy(t, 0, okm, pos, toCopy)
            pos += toCopy
            counter++
        }
        return okm
    }

    fun hmacSha256(key: ByteArray, data: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(data)
    }

    fun sha256(data: ByteArray): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(data)
    }

    fun bytesToHex(bytes: ByteArray): String {
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) {
            sb.append(String.format("%02x", b))
        }
        return sb.toString()
    }
}

package com.ironkey.ironkey_mobile.crypto

import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets

/**
 * Serializador JSON Canônico compatível com Python:
 * `json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=False)`
 */
object CanonicalJson {

    fun canonicalize(value: Any?): String {
        return when {
            value == null || value == JSONObject.NULL -> "null"
            value is Boolean -> if (value) "true" else "false"
            value is Number -> value.toString()
            value is String -> escapeString(value)
            value is Map<*, *> -> {
                val sortedKeys = value.keys.filterNotNull().map { it.toString() }.sorted()
                val pairs = sortedKeys.map { key ->
                    "${escapeString(key)}:${canonicalize(value[key])}"
                }
                "{${pairs.joinToString(",")}}"
            }
            value is JSONObject -> {
                val keys = mutableListOf<String>()
                val it = value.keys()
                while (it.hasNext()) {
                    keys.add(it.next())
                }
                keys.sort()
                val pairs = keys.map { key ->
                    "${escapeString(key)}:${canonicalize(value.get(key))}"
                }
                "{${pairs.joinToString(",")}}"
            }
            value is List<*> -> {
                val items = value.map { canonicalize(it) }
                "[${items.joinToString(",")}]"
            }
            value is JSONArray -> {
                val items = (0 until value.length()).map { idx ->
                    canonicalize(value.get(idx))
                }
                "[${items.joinToString(",")}]"
            }
            else -> escapeString(value.toString())
        }
    }

    fun canonicalBytes(value: Any?): ByteArray {
        return canonicalize(value).toByteArray(StandardCharsets.UTF_8)
    }

    private fun escapeString(s: String): String {
        val sb = StringBuilder("\"")
        for (c in s) {
            when (c) {
                '"' -> sb.append("\\\"")
                '\\' -> sb.append("\\\\")
                '\b' -> sb.append("\\b")
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                '\t' -> sb.append("\\t")
                '\u000c' -> sb.append("\\f")
                else -> {
                    if (c.code in 0x00..0x1F) {
                        sb.append(String.format("\\u%04x", c.code))
                    } else {
                        sb.append(c)
                    }
                }
            }
        }
        sb.append("\"")
        return sb.toString()
    }
}

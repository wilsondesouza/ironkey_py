package com.ironkey.ironkey_mobile.sync

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Ponte com o Android Storage Access Framework (SAF) para persistência de pasta em nuvem.
 */
class SafStorageBridge(private val context: Context) {

    companion object {
        const val SYNC_BLOB_NAME = "ironkeypy-sync.ikbak"
        const val MANIFEST_NAME = "ironkeypy-sync.manifest.json"
        const val TEMP_BLOB_NAME = "ironkeypy-sync.ikbak.tmp"
        const val TEMP_MANIFEST_NAME = "ironkeypy-sync.manifest.json.tmp"
    }

    fun persistTreeUriPermission(treeUri: Uri, flags: Int? = null) {
        val takeFlags = (flags ?: (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)) and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            context.contentResolver.takePersistableUriPermission(treeUri, takeFlags)
        } catch (e: Throwable) {
            // Ignora se o provider SAF não der suporte a persistable ou se a flag for restrita
        }
    }

    fun readRemoteBlob(treeUri: Uri): ByteArray? {
        return try {
            val tree = DocumentFile.fromTreeUri(context, treeUri) ?: return null
            var file = tree.findFile(SYNC_BLOB_NAME)
            if (file == null) {
                file = tree.listFiles().firstOrNull { it.name?.equals(SYNC_BLOB_NAME, ignoreCase = true) == true }
            }
            if (file == null) return null
            readFileBytes(file.uri)
        } catch (e: Throwable) {
            null
        }
    }

    fun readRemoteManifest(treeUri: Uri): String? {
        return try {
            val tree = DocumentFile.fromTreeUri(context, treeUri) ?: return null
            var file = tree.findFile(MANIFEST_NAME)
            if (file == null) {
                file = tree.listFiles().firstOrNull { it.name?.equals(MANIFEST_NAME, ignoreCase = true) == true }
            }
            if (file == null) return null
            val bytes = readFileBytes(file.uri) ?: return null
            String(bytes, Charsets.UTF_8)
        } catch (e: Throwable) {
            null
        }
    }

    fun listConflictCopies(treeUri: Uri): List<Pair<String, ByteArray>> {
        val results = mutableListOf<Pair<String, ByteArray>>()
        try {
            val tree = DocumentFile.fromTreeUri(context, treeUri) ?: return emptyList()
            for (file in tree.listFiles()) {
                val name = file.name ?: continue
                if (name == SYNC_BLOB_NAME || name == MANIFEST_NAME) continue
                if (name.startsWith("ironkeypy-sync") && name.endsWith(".ikbak")) {
                    val bytes = readFileBytes(file.uri)
                    if (bytes != null) {
                        results.add(Pair(name, bytes))
                    }
                }
            }
        } catch (e: Throwable) {
            // ignore
        }
        return results
    }

    fun writeRemoteFiles(treeUri: Uri, blobBytes: ByteArray, manifestJsonStr: String): Boolean {
        return try {
            val tree = DocumentFile.fromTreeUri(context, treeUri) ?: return false

            // 1. Grava ou sobrescreve o arquivo de dados
            var blobFile = tree.findFile(SYNC_BLOB_NAME)
            if (blobFile == null) {
                blobFile = tree.listFiles().firstOrNull { it.name?.equals(SYNC_BLOB_NAME, ignoreCase = true) == true }
            }
            if (blobFile == null) {
                blobFile = tree.createFile("application/octet-stream", SYNC_BLOB_NAME) ?: return false
            }
            if (!writeFileBytes(blobFile.uri, blobBytes)) return false

            // 2. Grava ou sobrescreve o manifesto autenticado
            var manifestFile = tree.findFile(MANIFEST_NAME)
            if (manifestFile == null) {
                manifestFile = tree.listFiles().firstOrNull { it.name?.equals(MANIFEST_NAME, ignoreCase = true) == true }
            }
            if (manifestFile == null) {
                manifestFile = tree.createFile("application/json", MANIFEST_NAME) ?: return false
            }
            writeFileBytes(manifestFile.uri, manifestJsonStr.toByteArray(Charsets.UTF_8))
        } catch (e: Throwable) {
            false
        }
    }

    private fun readFileBytes(uri: Uri): ByteArray? {
        return try {
            context.contentResolver.openInputStream(uri)?.use { input: InputStream ->
                val buffer = ByteArrayOutputStream()
                val temp = ByteArray(8192)
                var read: Int
                while (input.read(temp).also { read = it } != -1) {
                    buffer.write(temp, 0, read)
                }
                buffer.toByteArray()
            }
        } catch (e: Throwable) {
            null
        }
    }

    private fun writeFileBytes(uri: Uri, bytes: ByteArray): Boolean {
        return try {
            context.contentResolver.openOutputStream(uri, "rwt")?.use { output: OutputStream ->
                output.write(bytes)
                output.flush()
                true
            } ?: context.contentResolver.openOutputStream(uri, "w")?.use { output: OutputStream ->
                output.write(bytes)
                output.flush()
                true
            } ?: false
        } catch (e: Throwable) {
            false
        }
    }
}

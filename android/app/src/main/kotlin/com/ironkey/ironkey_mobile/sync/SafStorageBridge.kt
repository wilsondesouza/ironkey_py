package com.ironkey.ironkey_mobile.sync

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Ponte resiliente com o Android Storage Access Framework (SAF) para persistência de pasta em nuvem.
 * Gerencia leitura, detecção de cópias de conflito de serviços de nuvem (Drive, Dropbox, OneDrive)
 * e escrita atômica com limpeza de duplicatas.
 */
class SafStorageBridge(private val context: Context) {

    companion object {
        const val SYNC_BLOB_NAME = "ironkeypy-sync.ikbak"
        const val MANIFEST_NAME = "ironkeypy-sync.manifest.json"
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
            val matching = tree.listFiles().filter { it.name?.equals(SYNC_BLOB_NAME, ignoreCase = true) == true }
            val file = matching.maxByOrNull { it.lastModified() } ?: tree.findFile(SYNC_BLOB_NAME) ?: return null
            readFileBytes(file.uri)
        } catch (e: Throwable) {
            null
        }
    }

    fun readRemoteManifest(treeUri: Uri): String? {
        return try {
            val tree = DocumentFile.fromTreeUri(context, treeUri) ?: return null
            val matching = tree.listFiles().filter { it.name?.equals(MANIFEST_NAME, ignoreCase = true) == true }
            val file = matching.maxByOrNull { it.lastModified() } ?: tree.findFile(MANIFEST_NAME) ?: return null
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
            val allFiles = tree.listFiles()
            
            // Localiza o arquivo principal para não listá-lo como cópia de conflito
            val mainBlob = allFiles.filter { it.name?.equals(SYNC_BLOB_NAME, ignoreCase = true) == true }
                .maxByOrNull { it.lastModified() }

            for (file in allFiles) {
                val name = file.name ?: continue
                val nameLower = name.lowercase()

                if (file.uri == mainBlob?.uri) continue
                if (nameLower == MANIFEST_NAME.lowercase()) continue
                if (nameLower.endsWith(".tmp") || nameLower.startsWith(".")) continue

                // Detecta qualquer variante de sincronização gerada por nuvens
                val isSyncVariant = nameLower.contains("ironkeypy-sync") && !nameLower.contains("manifest")
                if (isSyncVariant) {
                    val bytes = readFileBytes(file.uri)
                    if (bytes != null && bytes.isNotEmpty()) {
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
            val allFiles = tree.listFiles()

            // 1. Grava o arquivo principal de dados (e limpa duplicatas exatas se houver)
            val blobMatches = allFiles.filter { it.name?.equals(SYNC_BLOB_NAME, ignoreCase = true) == true }
            val blobFile = if (blobMatches.isNotEmpty()) {
                val target = blobMatches.maxByOrNull { it.lastModified() }!!
                // Deleta cópias duplicadas com o mesmo nome para evitar ambiguidade no SAF
                for (dup in blobMatches) {
                    if (dup.uri != target.uri) {
                        try { dup.delete() } catch (_: Throwable) {}
                    }
                }
                target
            } else {
                tree.createFile("application/octet-stream", SYNC_BLOB_NAME) ?: return false
            }

            if (!writeFileBytes(blobFile.uri, blobBytes)) return false

            // 2. Grava o manifesto autenticado
            val manifestMatches = allFiles.filter { it.name?.equals(MANIFEST_NAME, ignoreCase = true) == true }
            val manifestFile = if (manifestMatches.isNotEmpty()) {
                val target = manifestMatches.maxByOrNull { it.lastModified() }!!
                for (dup in manifestMatches) {
                    if (dup.uri != target.uri) {
                        try { dup.delete() } catch (_: Throwable) {}
                    }
                }
                target
            } else {
                tree.createFile("application/json", MANIFEST_NAME) ?: return false
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

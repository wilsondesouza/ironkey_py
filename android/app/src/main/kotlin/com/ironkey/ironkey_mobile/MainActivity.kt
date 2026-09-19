package com.ironkey.ironkey_mobile

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.ironkey.ironkey_mobile.crypto.CryptoEngine
import com.ironkey.ironkey_mobile.sync.EnrollmentManager
import com.ironkey.ironkey_mobile.sync.SafStorageBridge
import com.ironkey.ironkey_mobile.sync.SyncEngineNative
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Base64

class MainActivity : FlutterActivity() {

    companion object {
        // Mantém a instância CryptoEngine compartilhada entre possíveis recriações de Activity
        private val sharedCryptoEngine = CryptoEngine()
    }

    private val cryptoEngine = sharedCryptoEngine
    private lateinit var safStorage: SafStorageBridge
    private lateinit var syncEngineNative: SyncEngineNative

    private val CRYPTO_CHANNEL = "com.ironkey.crypto"
    private val STORAGE_CHANNEL = "com.ironkey.storage"
    private val SYNC_CHANNEL = "com.ironkey.sync_native"

    private var pendingPickerResult: MethodChannel.Result? = null
    private val REQUEST_CODE_PICK_DIRECTORY = 9901

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        safStorage = SafStorageBridge(applicationContext)
        syncEngineNative = SyncEngineNative(cryptoEngine)

        // -------------------------------------------------------------
        // CANAL CRIPTOGRÁFICO NATIVO (Argon2id, AES-GCM, HKDF)
        // -------------------------------------------------------------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRYPTO_CHANNEL).setMethodCallHandler { call, result ->
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    when (call.method) {
                        "unlock" -> {
                            val password = call.argument<String>("masterPassword") ?: ""
                            val configJson = call.argument<String>("configJson") ?: ""
                            val success = cryptoEngine.unlock(password, configJson)
                            withContext(Dispatchers.Main) { result.success(success) }
                        }
                        "lock" -> {
                            cryptoEngine.lock()
                            withContext(Dispatchers.Main) { result.success(true) }
                        }
                        "isUnlocked" -> {
                            withContext(Dispatchers.Main) { result.success(cryptoEngine.isUnlocked) }
                        }
                        "encryptRecord" -> {
                            val plaintext = call.argument<String>("plaintext") ?: ""
                            val encrypted = cryptoEngine.encryptRecord(plaintext)
                            withContext(Dispatchers.Main) { result.success(encrypted) }
                        }
                        "decryptRecord" -> {
                            val ciphertext = call.argument<String>("ciphertext") ?: ""
                            val decrypted = cryptoEngine.decryptRecord(ciphertext)
                            withContext(Dispatchers.Main) { result.success(decrypted) }
                        }
                        "readEnrollment" -> {
                            val ikenrJson = call.argument<String>("ikenrJson") ?: ""
                            val password = call.argument<String>("masterPassword") ?: ""
                            val data = EnrollmentManager.readEnrollment(ikenrJson, password)
                            val map = mapOf(
                                "headerJson" to data.headerJsonStr,
                                "createdAt" to data.createdAt,
                                "sourceDevice" to data.sourceDevice
                            )
                            withContext(Dispatchers.Main) { result.success(map) }
                        }
                        else -> withContext(Dispatchers.Main) { result.notImplemented() }
                    }
                } catch (e: Throwable) {
                    withContext(Dispatchers.Main) {
                        result.error("CRYPTO_ERROR", e.message, null)
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // CANAL STORAGE ACCESS FRAMEWORK (SAF)
        // -------------------------------------------------------------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDirectory" -> {
                    pendingPickerResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                            )
                        }
                        startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
                    } catch (e: Throwable) {
                        pendingPickerResult = null
                        result.error("PICKER_ERROR", e.message, null)
                    }
                }
                "persistTreeUri" -> {
                    try {
                        val uriStr = call.argument<String>("treeUri") ?: ""
                        val uri = Uri.parse(uriStr)
                        safStorage.persistTreeUriPermission(uri)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "readRemoteFiles" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val uriStr = call.argument<String>("treeUri") ?: ""
                            val uri = Uri.parse(uriStr)
                            val blob = safStorage.readRemoteBlob(uri)
                            val manifest = safStorage.readRemoteManifest(uri)
                            val conflicts = safStorage.listConflictCopies(uri).map {
                                mapOf(
                                    "filename" to it.first,
                                    "dataBase64" to Base64.getEncoder().encodeToString(it.second)
                                )
                            }
                            val response = mapOf(
                                "hasBlob" to (blob != null),
                                "blobBase64" to (blob?.let { Base64.getEncoder().encodeToString(it) } ?: ""),
                                "manifest" to (manifest ?: ""),
                                "conflicts" to conflicts
                            )
                            withContext(Dispatchers.Main) { result.success(response) }
                        } catch (e: Throwable) {
                            withContext(Dispatchers.Main) { result.error("STORAGE_ERROR", e.message, null) }
                        }
                    }
                }
                "writeRemoteFiles" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val uriStr = call.argument<String>("treeUri") ?: ""
                            val blobBase64 = call.argument<String>("blobBase64") ?: ""
                            val manifestStr = call.argument<String>("manifest") ?: ""
                            val blobBytes = Base64.getDecoder().decode(blobBase64)

                            val success = safStorage.writeRemoteFiles(Uri.parse(uriStr), blobBytes, manifestStr)
                            withContext(Dispatchers.Main) { result.success(success) }
                        } catch (e: Throwable) {
                            withContext(Dispatchers.Main) { result.error("STORAGE_ERROR", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // -------------------------------------------------------------
        // CANAL DE OPERAÇÕES NATIVAS DE SYNC
        // -------------------------------------------------------------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYNC_CHANNEL).setMethodCallHandler { call, result ->
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    when (call.method) {
                        "readSyncBlob" -> {
                            val blobBase64 = call.argument<String>("blobBase64") ?: ""
                            val blobBytes = Base64.getDecoder().decode(blobBase64)
                            val doc = syncEngineNative.readSyncBlob(blobBytes)
                            val map = mapOf(
                                "generation" to doc.generation,
                                "vaultId" to doc.vaultId,
                                "entries" to doc.entries,
                                "purgedUids" to doc.purgedUids
                            )
                            withContext(Dispatchers.Main) { result.success(map) }
                        }
                        "verifyManifest" -> {
                            val manifestStr = call.argument<String>("manifest") ?: ""
                            val blobBase64 = call.argument<String>("blobBase64") ?: ""
                            val blobBytes = Base64.getDecoder().decode(blobBase64)
                            val res = syncEngineNative.verifyManifestDetailed(manifestStr, blobBytes)
                            withContext(Dispatchers.Main) { result.success(res) }
                        }
                        "buildSyncPayload" -> {
                            val generation = call.argument<Number>("generation")?.toLong() ?: 0L
                            val entries = call.argument<List<Map<String, Any?>>>("entries") ?: emptyList()
                            val deviceId = call.argument<String>("deviceId") ?: ""
                            val purgedUids = call.argument<List<String>>("purgedUids") ?: emptyList()

                            val (blobBytes, manifestStr) = syncEngineNative.buildSyncPayload(generation, entries, deviceId, purgedUids)
                            val map = mapOf(
                                "blobBase64" to Base64.getEncoder().encodeToString(blobBytes),
                                "manifest" to manifestStr
                            )
                            withContext(Dispatchers.Main) { result.success(map) }
                        }
                        else -> withContext(Dispatchers.Main) { result.notImplemented() }
                    }
                } catch (e: Throwable) {
                    withContext(Dispatchers.Main) {
                        result.error("SYNC_NATIVE_ERROR", e.message, null)
                    }
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_DIRECTORY) {
            val result = pendingPickerResult
            pendingPickerResult = null
            try {
                if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    val treeUri: Uri = data.data!!
                    safStorage.persistTreeUriPermission(treeUri, data.flags)

                    // Persiste imediatamente no SharedPreferences nativo do Android
                    try {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putString("flutter.sync_tree_uri", treeUri.toString()).apply()
                    } catch (t: Throwable) {
                        // ignore
                    }

                    result?.success(treeUri.toString())
                } else {
                    result?.success(null)
                }
            } catch (e: Throwable) {
                result?.error("PICKER_ERROR", e.message, null)
            }
        }
    }
}

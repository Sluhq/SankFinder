package com.example.sankfinder.data

import android.content.Context
import android.util.Base64
import android.util.Log
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.sankfinder.security.CryptoHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

private val Context.dataStore by preferencesDataStore(name = "visit_history")

object VisitHistoryStore {
    private const val TAG = "VisitHistoryStore"
    private const val FILE_NAME = "sankfinder_history.json"
    private val HISTORY_KEY = stringPreferencesKey("history")

    suspend fun save(context: Context, history: List<VisitHistory>) = withContext(Dispatchers.IO) {
        try {
            val serializableList = history.map { VisitHistorySerializable.from(it) }
            val json = Json.encodeToString(serializableList)
            val jsonBytes = json.toByteArray(Charsets.UTF_8)

            // Šifriraj podatke z AES-256-GCM (12-bajtni IV + šifrirana vsebina + AuthTag)
            val encryptedBytes = CryptoHelper.encrypt(jsonBytes)

            // 1. Shrani v šifrirano datoteko v internem pomnilniku
            val file = File(context.filesDir, FILE_NAME)
            file.writeBytes(encryptedBytes)

            // 2. Shrani še v DataStore (Base64) za redundanco
            val encryptedBase64 = Base64.encodeToString(encryptedBytes, Base64.NO_WRAP)
            context.dataStore.edit { prefs ->
                prefs[HISTORY_KEY] = encryptedBase64
            }
            Log.d(TAG, "Zgodovina obiskov (${history.size}) uspešno šifrirana z AES-256-GCM in shranjena.")
        } catch (e: Exception) {
            Log.e(TAG, "Napaka pri šifriranju/shranjevanju zgodovine obiskov", e)
        }
    }

    suspend fun load(context: Context): List<VisitHistory> = withContext(Dispatchers.IO) {
        val file = File(context.filesDir, FILE_NAME)
        var rawBytes: ByteArray? = null

        if (file.exists() && file.length() > 0) {
            try {
                rawBytes = file.readBytes()
            } catch (e: Exception) {
                Log.w(TAG, "Napaka pri branju datoteke $FILE_NAME", e)
            }
        }

        // Če datoteke še ni, poskusi iz DataStore
        if (rawBytes == null) {
            try {
                val prefs = context.dataStore.data.first()
                val stored = prefs[HISTORY_KEY]
                if (stored != null && stored.isNotBlank()) {
                    rawBytes = if (stored.startsWith("[") || stored.startsWith("{")) {
                        stored.toByteArray(Charsets.UTF_8)
                    } else {
                        Base64.decode(stored, Base64.NO_WRAP)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Napaka pri branju DataStore", e)
            }
        }

        if (rawBytes == null || rawBytes.isEmpty()) {
            return@withContext emptyList()
        }

        // 1. Samodejna varna migracija: če se začne z '[' (0x5B) ali '{' (0x7B), gre za star nešifriran JSON
        val firstByte = rawBytes[0].toInt()
        if (firstByte == 0x5B || firstByte == 0x7B) {
            try {
                val unencryptedJson = String(rawBytes, Charsets.UTF_8)
                val serializableList = Json.decodeFromString<List<VisitHistorySerializable>>(unencryptedJson)
                val visits = serializableList.map { it.toVisitHistory() }
                Log.i(TAG, "Zaznana stara nešifrirana zgodovina (${visits.size} obiskov). Samodejno šifriram z AES-256-GCM...")
                // Takoj ponovno shrani v varno šifrirani obliki
                save(context, visits)
                return@withContext visits
            } catch (e: Exception) {
                Log.e(TAG, "Napaka pri migraciji nešifrirane zgodovine", e)
            }
        }

        // 2. Dešifriranje s strojno pospešenim AES-256-GCM preko AndroidKeyStore
        try {
            val decryptedBytes = CryptoHelper.decrypt(rawBytes)
            val json = String(decryptedBytes, Charsets.UTF_8)
            val serializableList = Json.decodeFromString<List<VisitHistorySerializable>>(json)
            return@withContext serializableList.map { it.toVisitHistory() }
        } catch (e: Exception) {
            Log.e(TAG, "Napaka pri dešifriranju zgodovine obiskov", e)
            return@withContext emptyList()
        }
    }
}

package com.example.sankfinder.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.dataStore by preferencesDataStore(name = "visit_history")

object VisitHistoryStore {
    private val HISTORY_KEY = stringPreferencesKey("history")

    suspend fun save(context: Context, history: List<VisitHistory>) {
        val serializableList = history.map { VisitHistorySerializable.from(it) }
        val json = Json.encodeToString(serializableList)
        context.dataStore.edit { prefs ->
            prefs[HISTORY_KEY] = json
        }
    }

    suspend fun load(context: Context): List<VisitHistory> {
        val prefs = context.dataStore.data.first()
        val json = prefs[HISTORY_KEY] ?: return emptyList()
        val serializableList = Json.decodeFromString<List<VisitHistorySerializable>>(json)
        return serializableList.map { it.toVisitHistory() }
    }
}

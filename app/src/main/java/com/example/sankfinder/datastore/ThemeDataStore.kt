package com.example.sankfinder.datastore

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

val Context.dataStore by preferencesDataStore(name = "settings")

class ThemeDataStore(private val context: Context) {

    companion object {
        private val DARK_THEME_KEY = booleanPreferencesKey("dark_theme")
        private val SEARCH_RADIUS_KEY = intPreferencesKey("search_radius")
        private val NOTIFICATIONS_KEY = booleanPreferencesKey("push_notifications")
        private val SOUND_ALERTS_KEY = booleanPreferencesKey("sound_alerts")
        private val SAFE_TRIP_KEY = booleanPreferencesKey("safe_trip")
        private val LOKAL_LIMIT_KEY = intPreferencesKey("lokal_limit")
    }

    val isDarkTheme: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[DARK_THEME_KEY] ?: false
    }

    val searchRadius: Flow<Int> = context.dataStore.data.map { preferences ->
        preferences[SEARCH_RADIUS_KEY] ?: 2000 // default 2000m
    }

    val lokalLimit: Flow<Int> = context.dataStore.data.map { preferences ->
        preferences[LOKAL_LIMIT_KEY] ?: 20 // default 20
    }

    val pushNotifications: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[NOTIFICATIONS_KEY] ?: true
    }

    val soundAlerts: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[SOUND_ALERTS_KEY] ?: true
    }

    val safeTrip: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[SAFE_TRIP_KEY] ?: true
    }

    suspend fun setLokalLimit(limit: Int) {
        context.dataStore.edit { preferences ->
            preferences[LOKAL_LIMIT_KEY] = limit
        }
    }

    suspend fun setDarkTheme(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[DARK_THEME_KEY] = enabled
        }
    }

    suspend fun setSearchRadius(radiusMeters: Int) {
        context.dataStore.edit { preferences ->
            preferences[SEARCH_RADIUS_KEY] = radiusMeters
        }
    }

    suspend fun setPushNotifications(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[NOTIFICATIONS_KEY] = enabled
        }
    }

    suspend fun setSoundAlerts(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[SOUND_ALERTS_KEY] = enabled
        }
    }

    suspend fun setSafeTrip(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[SAFE_TRIP_KEY] = enabled
        }
    }
}
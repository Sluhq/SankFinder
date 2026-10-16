package com.example.sankfinder.network

import android.content.Context
import android.os.Build
import android.util.Log
import com.example.sankfinder.notifications.SankNotificationHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.net.URLEncoder
import java.util.UUID

private const val TAG = "GlobalSyncManager"

data class PushNotificationEvent(
    val id: Int,
    val title: String,
    val message: String,
    val category: String,
    val timestamp: Long = System.currentTimeMillis()
)

data class FeaturedPubInfo(
    val name: String,
    val address: String,
    val lat: Double?,
    val lon: Double?,
    val note: String
)

/**
 * GlobalSyncManager vzdržuje trajno, varovano povezavo celotne aplikacije ŠankFinder
 * z osrednjo upravno ploščo. Omogoča:
 *  - Prejemanje sistemskih potisnih obvestil (push notifications) na raven celotnega telefona
 *  - Poročanje o stanju / aktivnem zaslonu (telemetrija za skrbnika)
 *  - Samodejno obnavljanje povezave ob prekinitvah
 */
object GlobalSyncManager {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var appContext: Context? = null
    private var activeWebSocket: WebSocket? = null
    private var deviceId: String = ""
    private var currentScreenName: String = "Glavna stran"
    private var isStarted = false

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _pushEvents = MutableSharedFlow<PushNotificationEvent>(extraBufferCapacity = 10)
    val pushEvents: SharedFlow<PushNotificationEvent> = _pushEvents.asSharedFlow()

    private val _motd = MutableStateFlow<String?>(null)
    val motd: StateFlow<String?> = _motd.asStateFlow()

    private val _featuredPub = MutableStateFlow<FeaturedPubInfo?>(null)
    val featuredPub: StateFlow<FeaturedPubInfo?> = _featuredPub.asStateFlow()

    private val _latestVersion = MutableStateFlow<String?>("1.2.1")
    val latestVersion: StateFlow<String?> = _latestVersion.asStateFlow()

    private val _isOutdated = MutableStateFlow(false)
    val isOutdated: StateFlow<Boolean> = _isOutdated.asStateFlow()

    private val _versionNotes = MutableStateFlow<String?>("")
    val versionNotes: StateFlow<String?> = _versionNotes.asStateFlow()

    private val _hasAcceptedTerms = MutableStateFlow(false)
    val hasAcceptedTerms: StateFlow<Boolean> = _hasAcceptedTerms.asStateFlow()

    fun isVersionOlder(current: String, latest: String): Boolean {
        return try {
            val currParts = current.split(".").map { it.filter { c -> c.isDigit() }.toIntOrNull() ?: 0 }
            val latestParts = latest.split(".").map { it.filter { c -> c.isDigit() }.toIntOrNull() ?: 0 }
            val maxLen = maxOf(currParts.size, latestParts.size)
            for (i in 0 until maxLen) {
                val c = currParts.getOrElse(i) { 0 }
                val l = latestParts.getOrElse(i) { 0 }
                if (c < l) return true
                if (c > l) return false
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    fun isTermsAccepted(context: Context? = null): Boolean {
        if (_hasAcceptedTerms.value) return true
        val ctx = context ?: appContext ?: return false
        val prefs = ctx.getSharedPreferences("sankfinder_global", Context.MODE_PRIVATE)
        val accepted = prefs.getBoolean("has_accepted_terms", false)
        _hasAcceptedTerms.value = accepted
        return accepted
    }

    fun reportTermsAccepted(context: Context? = null) {
        _hasAcceptedTerms.value = true
        val ctx = context ?: appContext
        ctx?.let {
            val prefs = it.getSharedPreferences("sankfinder_global", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("has_accepted_terms", true).apply()
        }

        try {
            val json = JSONObject().apply {
                put("type", "terms_accepted")
                put("accepted", true)
                put("deviceId", deviceId)
            }
            activeWebSocket?.send(json.toString())
        } catch (e: Exception) {
            Log.w(TAG, "Napaka pri oddaji potrditve pogojev prek WS: ${e.message}")
        }

        scope.launch {
            for (hostInfo in hosts) {
                try {
                    val scheme = if (hostInfo.second) "https" else "http"
                    val url = "$scheme://${hostInfo.first}/api/app/terms/accept"
                    val bodyJson = JSONObject().apply {
                        put("deviceId", deviceId)
                        put("clientType", "android")
                        put("accepted", true)
                    }
                    val body = okhttp3.RequestBody.create(
                        okhttp3.MediaType.parse("application/json; charset=utf-8"),
                        bodyJson.toString()
                    )
                    val request = Request.Builder().url(url).post(body).build()
                    val response = NetworkClient.okHttpClient.newCall(request).execute()
                    if (response.isSuccessful) {
                        Log.d(TAG, "Potrditev pogojev uspesno poslana na ${hostInfo.first}")
                        break
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Neuspesno posiljanje pogojev na ${hostInfo.first}: ${e.message}")
                }
            }
        }
    }

    fun init(context: Context) {
        if (isStarted) return
        isStarted = true
        appContext = context.applicationContext

        val prefs = context.getSharedPreferences("sankfinder_global", Context.MODE_PRIVATE)
        _hasAcceptedTerms.value = prefs.getBoolean("has_accepted_terms", false)
        deviceId = prefs.getString("device_id", null) ?: run {
            val newId = "dev_" + UUID.randomUUID().toString().take(8)
            prefs.edit().putString("device_id", newId).apply()
            newId
        }

        SankNotificationHelper.createGlobalAnnouncementChannel(context)

        fetchInitialConfig()
        startSyncLoop()
    }

    fun fetchInitialConfig() {
        scope.launch {
            for (hostInfo in hosts) {
                try {
                    val scheme = if (hostInfo.second) "https" else "http"
                    val url = "$scheme://${hostInfo.first}/api/app/config"
                    val request = Request.Builder().url(url).build()
                    val response = NetworkClient.okHttpClient.newCall(request).execute()
                    if (response.isSuccessful) {
                        val body = response.body()?.string() ?: ""
                        val json = JSONObject(body)
                        if (json.optBoolean("success", false)) {
                            val msg = json.optString("motd", "")
                            if (msg.isNotBlank()) _motd.value = msg
                            val pubObj = json.optJSONObject("featuredPub")
                            if (pubObj != null) {
                                val latVal = pubObj.optString("lat").toDoubleOrNull()
                                val lonVal = pubObj.optString("lon").toDoubleOrNull()
                                _featuredPub.value = FeaturedPubInfo(
                                    name = pubObj.optString("name", "Šank Tedna"),
                                    address = pubObj.optString("address", ""),
                                    lat = latVal,
                                    lon = lonVal,
                                    note = pubObj.optString("note", "")
                                )
                            }
                            val verObj = json.optJSONObject("versions")
                            if (verObj != null) {
                                val latest = verObj.optString("android", verObj.optString("latestAndroid", "1.2.1"))
                                val notes = verObj.optString("notes", "")
                                _latestVersion.value = latest
                                _versionNotes.value = notes
                                val current = try { com.example.sankfinder.BuildConfig.VERSION_NAME } catch (e: Exception) { "1.2.1" }
                                _isOutdated.value = isVersionOlder(current, latest)
                            }
                            break
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Neuspešen klic na /api/app/config (${hostInfo.first}): ${e.message}")
                }
            }
        }
    }

    fun reportScreen(screen: String) {
        currentScreenName = screen
        sendScreenReport(screen)
    }

    private fun sendScreenReport(screen: String) {
        try {
            val appVer = try { com.example.sankfinder.BuildConfig.VERSION_NAME } catch (e: Exception) { "1.2.1" }
            val json = JSONObject().apply {
                put("type", "screen_change")
                put("screen", screen)
                put("version", appVer)
            }
            activeWebSocket?.send(json.toString())
        } catch (e: Exception) {
            Log.w(TAG, "Napaka pri oddaji zaslona: ${e.message}")
        }
    }

    private val hosts = listOf(
        Pair("sankfinder.sluga.me", true),
        Pair("192.168.200.209:8080", false)
    )
    private var currentHostIndex = 0

    private fun startSyncLoop() {
        scope.launch {
            while (true) {
                if (activeWebSocket == null) {
                    connect()
                }
                delay(6000)
            }
        }
    }

    private fun connect() {
        val model = "${Build.MANUFACTURER} ${Build.MODEL}"
        val encodedModel = URLEncoder.encode(model, "UTF-8")
        val encodedScreen = URLEncoder.encode(currentScreenName, "UTF-8")
        val os = "Android ${Build.VERSION.RELEASE}"
        val encodedOs = URLEncoder.encode(os, "UTF-8")

        val hostInfo = hosts[currentHostIndex]
        val scheme = if (hostInfo.second) "wss" else "ws"
        val appVersion = try { com.example.sankfinder.BuildConfig.VERSION_NAME } catch (e: Exception) { "1.2.1" }
        val termsParam = if (_hasAcceptedTerms.value) "1" else "0"
        val url = "$scheme://${hostInfo.first}/ws?clientType=app&deviceId=$deviceId&model=$encodedModel&os=$encodedOs&screen=$encodedScreen&version=$appVersion&terms=$termsParam"
        val request = Request.Builder().url(url).build()

        try {
            activeWebSocket = NetworkClient.webSocketOkHttpClient.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    Log.d(TAG, "Global WebSocket uspešno povezan z nadzorno ploščo prek ${hostInfo.first}!")
                    _isConnected.value = true
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    handleIncomingMessage(text)
                }

                override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                    webSocket.close(1000, null)
                    _isConnected.value = false
                    activeWebSocket = null
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    Log.w(TAG, "Global WebSocket začasna prekinitev na ${hostInfo.first}: ${t.message}")
                    _isConnected.value = false
                    activeWebSocket = null
                    // Preklopi na rezervnega gostitelja
                    currentHostIndex = (currentHostIndex + 1) % hosts.size
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Napaka pri vzpostavitvi povezave na ${hostInfo.first}: ${e.message}")
            activeWebSocket = null
            _isConnected.value = false
            currentHostIndex = (currentHostIndex + 1) % hosts.size
        }
    }

    private fun handleIncomingMessage(text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type")

            when (type) {
                "global_push" -> {
                    val notifId = json.optInt("id", (System.currentTimeMillis() % 100000).toInt())
                    val title = json.optString("title", "ŠankFinder Obvestilo")
                    val message = json.optString("message", "")
                    val category = json.optString("category", "splošno")

                    appContext?.let { ctx ->
                        // 1. Prikaži pravo sistemsko Android obvestilo v opravilni vrstici (tray)
                        SankNotificationHelper.showGlobalAppNotification(ctx, title, message, notifId)
                    }

                    // 2. Oddaj dogodek za prikaz v aplikaciji, če ima uporabnik odprt zaslon
                    _pushEvents.tryEmit(PushNotificationEvent(notifId, title, message, category))
                }

                "motd" -> {
                    val msg = json.optString("message", "")
                    _motd.value = if (msg.isBlank()) null else msg
                }

                "version_info", "app_version_update" -> {
                    val verObj = json.optJSONObject("versions") ?: json
                    val latest = verObj.optString("android", verObj.optString("latestAndroid", "1.2.1"))
                    val notes = verObj.optString("notes", "")
                    _latestVersion.value = latest
                    _versionNotes.value = notes
                    val current = try { com.example.sankfinder.BuildConfig.VERSION_NAME } catch (e: Exception) { "1.2.1" }
                    _isOutdated.value = isVersionOlder(current, latest)
                }

                "featured_pub" -> {
                    val pubObj = json.optJSONObject("pub")
                    if (pubObj != null) {
                        val latVal = pubObj.optString("lat").toDoubleOrNull()
                        val lonVal = pubObj.optString("lon").toDoubleOrNull()
                        _featuredPub.value = FeaturedPubInfo(
                            name = pubObj.optString("name", "Šank Tedna"),
                            address = pubObj.optString("address", ""),
                            lat = latVal,
                            lon = lonVal,
                            note = pubObj.optString("note", "")
                        )
                    } else {
                        _featuredPub.value = null
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Napaka pri branju globalnega sporočila: ${e.message}")
        }
    }
}

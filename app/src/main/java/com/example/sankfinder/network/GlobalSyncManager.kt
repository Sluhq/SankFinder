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

    fun init(context: Context) {
        if (isStarted) return
        isStarted = true
        appContext = context.applicationContext

        val prefs = context.getSharedPreferences("sankfinder_global", Context.MODE_PRIVATE)
        deviceId = prefs.getString("device_id", null) ?: run {
            val newId = "dev_" + UUID.randomUUID().toString().take(8)
            prefs.edit().putString("device_id", newId).apply()
            newId
        }

        SankNotificationHelper.createGlobalAnnouncementChannel(context)

        startSyncLoop()
    }

    fun reportScreen(screen: String) {
        currentScreenName = screen
        sendScreenReport(screen)
    }

    private fun sendScreenReport(screen: String) {
        try {
            val json = JSONObject().apply {
                put("type", "screen_change")
                put("screen", screen)
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
        val url = "$scheme://${hostInfo.first}/ws?clientType=app&deviceId=$deviceId&model=$encodedModel&os=$encodedOs&screen=$encodedScreen&version=1.0"
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
            }
        } catch (e: Exception) {
            Log.e(TAG, "Napaka pri branju globalnega sporočila: ${e.message}")
        }
    }
}

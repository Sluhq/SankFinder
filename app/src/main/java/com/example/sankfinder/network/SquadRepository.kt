package com.example.sankfinder.network

import android.util.Log
import com.example.sankfinder.data.SquadMember
import com.example.sankfinder.data.SquadMessage
import com.example.sankfinder.data.SquadRoom
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject

private const val TAG = "SquadRepository"
private val JSON_MEDIA_TYPE = MediaType.parse("application/json; charset=utf-8")

data class HostConfig(val host: String, val useSsl: Boolean)

class SquadRepository {

    // Kandidati: najprej javna varna domena, nato neposredni LAN naslov
    private val candidateHosts = listOf(
        HostConfig("sankfinder.sluga.me", true),
        HostConfig("192.168.200.209:8080", false)
    )

    var currentConfig: HostConfig = candidateHosts[0]

    private var activeWebSocket: WebSocket? = null

    /**
     * Očisti napako tako, da uporabnik vmesnika nikoli ne vidi internega IP-ja, vrat ali sistemskih sledi.
     */
    fun sanitizeError(e: Throwable): Exception {
        val raw = e.message ?: ""
        val isNetworkIssue = raw.contains("Failed to connect", ignoreCase = true) ||
                raw.contains("ConnectException", ignoreCase = true) ||
                raw.contains("SocketTimeoutException", ignoreCase = true) ||
                raw.contains("UnknownHostException", ignoreCase = true) ||
                raw.contains("ECONNREFUSED", ignoreCase = true) ||
                raw.contains("EHOSTUNREACH", ignoreCase = true) ||
                raw.contains("timeout", ignoreCase = true) ||
                raw.contains("192.168", ignoreCase = true) ||
                raw.contains("8080") ||
                raw.contains("ssl", ignoreCase = true) ||
                raw.contains("cert", ignoreCase = true)

        return if (isNetworkIssue) {
            Exception("Povezava s strežnikom ni uspela. Preveri internetno povezavo ali poskusi znova.")
        } else {
            val clean = raw.replace(Regex("\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}(:\\d+)?"), "[strežnik]")
            Exception(if (clean.isBlank()) "Prišlo je do neznane napake pri povezavi." else clean)
        }
    }

    private suspend fun <T> executeWithFallback(block: suspend (HostConfig) -> Result<T>): Result<T> {
        val order = listOf(currentConfig) + candidateHosts.filter { it != currentConfig }
        var lastError: Exception? = null

        for (cfg in order) {
            try {
                val res = block(cfg)
                if (res.isSuccess) {
                    currentConfig = cfg
                    return res
                } else {
                    val ex = res.exceptionOrNull()
                    if (ex is Exception) {
                        lastError = ex
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Napaka pri klicu na ${cfg.host}", e)
                lastError = e
            }
        }
        return Result.failure(sanitizeError(lastError ?: Exception("Strežnik ni dosegljiv")))
    }

    /**
     * Ustvari novo sobo za klapo.
     */
    suspend fun createRoom(roomName: String): Result<SquadRoom> = withContext(Dispatchers.IO) {
        executeWithFallback { cfg ->
            val scheme = if (cfg.useSsl) "https" else "http"
            val url = "$scheme://${cfg.host}/api/rooms/create"
            val timestamp = System.currentTimeMillis()
            val signature = com.example.sankfinder.security.CryptoHelper.generateSignature(timestamp, "android_app")
            val json = JSONObject().apply {
                put("name", roomName)
            }
            val body = RequestBody.create(JSON_MEDIA_TYPE, json.toString())
            val request = Request.Builder()
                .url(url)
                .header("X-Sank-Timestamp", timestamp.toString())
                .header("X-Sank-Signature", signature)
                .header("X-Device-Id", "android_app")
                .post(body)
                .build()

            val response: Response = NetworkClient.okHttpClient.newCall(request).execute()
            val respString = response.body()?.string() ?: ""

            if (!response.isSuccessful) {
                return@executeWithFallback Result.failure(
                    Exception(if (response.code() == 404) "Strežnik za klapo ni dosegljiv na tem naslovu (404)" else "Strežnik je vrnil napako (${response.code()})")
                )
            }

            val respObj = JSONObject(respString)
            if (respObj.optBoolean("success", false)) {
                val room = SquadRoom(
                    id = respObj.getString("roomId"),
                    code = respObj.getString("code"),
                    name = respObj.getString("name")
                )
                Result.success(room)
            } else {
                Result.failure(Exception(respObj.optString("error", "Neznana napaka pri ustvarjanju sobe")))
            }
        }
    }

    /**
     * Pridruži se obstoječi sobi s 4-mestno kodo.
     */
    suspend fun joinRoom(roomCode: String): Result<Triple<SquadRoom, List<SquadMember>, List<SquadMessage>>> = withContext(Dispatchers.IO) {
        val codeUpper = roomCode.trim().uppercase()
        executeWithFallback { cfg ->
            val scheme = if (cfg.useSsl) "https" else "http"
            val url = "$scheme://${cfg.host}/api/rooms/join"
            val timestamp = System.currentTimeMillis()
            val signature = com.example.sankfinder.security.CryptoHelper.generateSignature(timestamp, "android_app")
            val json = JSONObject().apply {
                put("code", codeUpper)
            }
            val body = RequestBody.create(JSON_MEDIA_TYPE, json.toString())
            val request = Request.Builder()
                .url(url)
                .header("X-Sank-Timestamp", timestamp.toString())
                .header("X-Sank-Signature", signature)
                .header("X-Device-Id", "android_app")
                .post(body)
                .build()

            val response: Response = NetworkClient.okHttpClient.newCall(request).execute()
            val respString = response.body()?.string() ?: ""

            if (!response.isSuccessful) {
                val msg = if (response.code() == 404) "Soba s kodo '$codeUpper' ne obstaja ali je že potekla." else "Strežnik je vrnil napako (${response.code()})"
                return@executeWithFallback Result.failure(Exception(msg))
            }

            val respObj = JSONObject(respString)
            if (respObj.optBoolean("success", false)) {
                val roomObj = respObj.getJSONObject("room")
                val room = SquadRoom(
                    id = roomObj.getString("id"),
                    code = roomObj.getString("code"),
                    name = roomObj.getString("name")
                )

                val membersList = mutableListOf<SquadMember>()
                val membersArr = respObj.optJSONArray("members") ?: JSONArray()
                for (i in 0 until membersArr.length()) {
                    val m = membersArr.getJSONObject(i)
                    membersList.add(
                        SquadMember(
                            id = m.getString("id"),
                            roomCode = m.getString("room_code"),
                            name = m.getString("name"),
                            lat = if (m.isNull("lat")) null else m.getDouble("lat"),
                            lon = if (m.isNull("lon")) null else m.getDouble("lon"),
                            drinksCount = m.optInt("drinks_count", 0),
                            lastSeen = if (m.isNull("last_seen")) null else m.optString("last_seen")
                        )
                    )
                }

                val messagesList = mutableListOf<SquadMessage>()
                val msgsArr = respObj.optJSONArray("messages") ?: JSONArray()
                for (i in 0 until msgsArr.length()) {
                    val msg = msgsArr.getJSONObject(i)
                    messagesList.add(
                        SquadMessage(
                            id = msg.optLong("id", i.toLong()),
                            roomCode = msg.getString("room_code"),
                            senderId = msg.getString("sender_id"),
                            senderName = msg.getString("sender_name"),
                            msgType = msg.optString("msg_type", "text"),
                            content = msg.getString("content"),
                            createdAt = msg.optString("created_at", "")
                        )
                    )
                }

                Result.success(Triple(room, membersList, messagesList))
            } else {
                Result.failure(Exception(respObj.optString("error", "Napaka pri pridružitvi sobi")))
            }
        }
    }

    /**
     * Vzpostavi trajno WebSocket povezavo za realnočasovni klepet in koordinate.
     */
    fun connectWebSocket(
        roomCode: String,
        userName: String,
        userId: String,
        onConnected: () -> Unit,
        onDisconnected: () -> Unit,
        onMessageReceived: (JSONObject) -> Unit
    ) {
        disconnectWebSocket()

        fun tryConnect(config: HostConfig, fallback: (() -> Unit)?) {
            val scheme = if (config.useSsl) "wss" else "ws"
            val timestamp = System.currentTimeMillis()
            val signature = com.example.sankfinder.security.CryptoHelper.generateSignature(timestamp, userId)
            val fullUrl = "$scheme://${config.host}/ws?code=${roomCode.trim().uppercase()}&name=${java.net.URLEncoder.encode(userName, "UTF-8")}&userId=$userId&t=$timestamp&sig=$signature"
            val request = Request.Builder()
                .url(fullUrl)
                .header("X-Sank-Timestamp", timestamp.toString())
                .header("X-Sank-Signature", signature)
                .header("X-Device-Id", userId)
                .build()

            activeWebSocket = NetworkClient.webSocketOkHttpClient.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    Log.d(TAG, "WebSocket uspešno odprt za sobo $roomCode preko ${config.host}")
                    currentConfig = config
                    onConnected()
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    try {
                        val json = JSONObject(text)
                        onMessageReceived(json)
                    } catch (e: Exception) {
                        Log.e(TAG, "Napaka pri branju WS sporočila", e)
                    }
                }

                override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                    webSocket.close(1000, null)
                    onDisconnected()
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    Log.w(TAG, "WebSocket napaka na ${config.host}: ${t.message}")
                    if (fallback != null) {
                        fallback()
                    } else {
                        onDisconnected()
                    }
                }
            })
        }

        // Poskusi najprej s trenutno uspešno konfiguracijo, če odpove pa z alternativo
        val alternate = candidateHosts.firstOrNull { it != currentConfig }
        tryConnect(currentConfig) {
            if (alternate != null) {
                Log.d(TAG, "Poskušam alternativni strežnik za WS: ${alternate.host}")
                tryConnect(alternate, null)
            } else {
                onDisconnected()
            }
        }
    }

    fun disconnectWebSocket() {
        try {
            activeWebSocket?.close(1000, "Odjava")
        } catch (e: Exception) {
            // Ignoriraj
        } finally {
            activeWebSocket = null
        }
    }

    /**
     * Pošlje novo besedilno sporočilo ali hitro akcijo.
     */
    fun sendChatMessage(content: String, msgType: String = "text") {
        val payload = JSONObject().apply {
            put("type", "chat_message")
            put("content", content)
            put("msgType", msgType)
        }
        activeWebSocket?.send(payload.toString())
    }

    /**
     * Pošlje posodobljene GPS koordinate (vsakih 5-10 sekund).
     */
    fun sendLocationUpdate(lat: Double, lon: Double, speed: Float = 0f) {
        val payload = JSONObject().apply {
            put("type", "location_update")
            put("lat", lat)
            put("lon", lon)
            put("speed", speed)
        }
        activeWebSocket?.send(payload.toString())
    }

    /**
     * Spremeni število popitih pijač (+1 ali -1).
     */
    fun sendDrinkUpdate(delta: Int = 1) {
        val payload = JSONObject().apply {
            put("type", "drink_update")
            put("delta", delta)
        }
        activeWebSocket?.send(payload.toString())
    }

    /**
     * Pošlje obvestilo o predvidenem prihodu ("Pridem čez X min").
     */
    fun sendEtaAlert(targetLokal: String, etaMinutes: Int) {
        val payload = JSONObject().apply {
            put("type", "eta_status")
            put("targetLokal", targetLokal)
            put("etaMinutes", etaMinutes)
        }
        activeWebSocket?.send(payload.toString())
    }
}

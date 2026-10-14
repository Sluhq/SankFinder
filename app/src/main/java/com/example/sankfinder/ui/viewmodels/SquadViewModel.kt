package com.example.sankfinder.ui.viewmodels

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.sankfinder.data.SquadMember
import com.example.sankfinder.data.SquadMessage
import com.example.sankfinder.data.SquadRoom
import com.example.sankfinder.network.SquadRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID

private const val TAG = "SquadViewModel"

class SquadViewModel(application: Application) : AndroidViewModel(application) {

    private val repository = SquadRepository()

    val myUserId: String = UUID.randomUUID().toString().substring(0, 8)
    private val _myUserName = MutableStateFlow("Prijatelj")
    val myUserName: StateFlow<String> = _myUserName.asStateFlow()

    private val _activeRoom = MutableStateFlow<SquadRoom?>(null)
    val activeRoom: StateFlow<SquadRoom?> = _activeRoom.asStateFlow()

    private val _members = MutableStateFlow<List<SquadMember>>(emptyList())
    val members: StateFlow<List<SquadMember>> = _members.asStateFlow()

    private val _messages = MutableStateFlow<List<SquadMessage>>(emptyList())
    val messages: StateFlow<List<SquadMessage>> = _messages.asStateFlow()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _bannerAlert = MutableStateFlow<String?>(null)
    val bannerAlert: StateFlow<String?> = _bannerAlert.asStateFlow()

    private var lastSentLat: Double? = null
    private var lastSentLon: Double? = null
    private var lastSentLocTime = 0L

    fun setUserName(name: String) {
        if (name.isNotBlank()) {
            _myUserName.value = name.trim()
        }
    }

    fun clearBanner() {
        _bannerAlert.value = null
    }

    fun clearError() {
        _errorMessage.value = null
    }

    /**
     * Ustvari novo Pivsko Klapo (sobo).
     */
    fun createSquad(roomName: String, hostName: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            setUserName(hostName)

            val name = if (roomName.isBlank()) "Pivska Klapa" else roomName.trim()
            val result = repository.createRoom(name)

            _isLoading.value = false
            result.onSuccess { room ->
                _activeRoom.value = room
                _members.value = listOf(
                    SquadMember(
                        id = myUserId,
                        roomCode = room.code,
                        name = _myUserName.value,
                        lat = lastSentLat,
                        lon = lastSentLon,
                        drinksCount = 0,
                        lastSeen = null
                    )
                )
                _messages.value = listOf(
                    SquadMessage(
                        id = 1L,
                        roomCode = room.code,
                        senderId = "system",
                        senderName = "ŠankFinder",
                        msgType = "system",
                        content = "Klapa '${room.name}' je ustvarjena! Koda za vstop je: ${room.code}",
                        createdAt = ""
                    )
                )
                startWebSocketConnection(room.code)
            }.onFailure { err ->
                _errorMessage.value = repository.sanitizeError(err).message
            }
        }
    }

    /**
     * Pridruži se obstoječi sobi s 4-mestno kodo.
     */
    fun joinSquad(roomCode: String, userName: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            setUserName(userName)

            val code = roomCode.trim().uppercase()
            val result = repository.joinRoom(code)

            _isLoading.value = false
            result.onSuccess { (room, memberList, msgList) ->
                _activeRoom.value = room
                _members.value = memberList
                _messages.value = msgList
                startWebSocketConnection(room.code)
            }.onFailure { err ->
                _errorMessage.value = repository.sanitizeError(err).message
            }
        }
    }

    private fun startWebSocketConnection(code: String) {
        repository.connectWebSocket(
            roomCode = code,
            userName = _myUserName.value,
            userId = myUserId,
            onConnected = {
                _isConnected.value = true
            },
            onDisconnected = {
                _isConnected.value = false
            },
            onMessageReceived = { json ->
                handleIncomingWsMessage(json)
            }
        )
    }

    private fun handleIncomingWsMessage(json: JSONObject) {
        viewModelScope.launch {
            when (json.optString("type")) {
                "member_joined" -> {
                    val name = json.optString("name", "Nekdo")
                    val uid = json.optString("userId")
                    val code = _activeRoom.value?.code ?: ""

                    val current = _members.value.toMutableList()
                    if (current.none { it.id == uid }) {
                        current.add(
                            SquadMember(
                                id = uid,
                                roomCode = code,
                                name = name,
                                lat = null,
                                lon = null,
                                drinksCount = 0,
                                lastSeen = null
                            )
                        )
                        _members.value = current
                    }
                    _bannerAlert.value = "$name se je pridružil klapi!"
                }

                "member_left" -> {
                    val name = json.optString("name", "Nekdo")
                    val uid = json.optString("userId")
                    _members.value = _members.value.filterNot { it.id == uid }
                    _bannerAlert.value = "$name je zapustil klapo."
                }

                "peer_location" -> {
                    val uid = json.optString("userId")
                    val lat = json.optDouble("lat", Double.NaN)
                    val lon = json.optDouble("lon", Double.NaN)

                    if (!lat.isNaN() && !lon.isNaN()) {
                        _members.value = _members.value.map { m ->
                            if (m.id == uid) {
                                m.copy(lat = lat, lon = lon)
                            } else m
                        }
                    }
                }

                "new_message" -> {
                    val msg = SquadMessage(
                        id = json.optLong("id", System.currentTimeMillis()),
                        roomCode = _activeRoom.value?.code ?: "",
                        senderId = json.optString("senderId"),
                        senderName = json.optString("senderName"),
                        msgType = json.optString("msgType", "text"),
                        content = json.optString("content"),
                        createdAt = json.optString("createdAt", "")
                    )
                    _messages.value = _messages.value + msg

                    if (msg.msgType == "round_call") {
                        val sender = msg.senderName
                        _bannerAlert.value = "$sender časti naslednjo rundo!"
                        com.example.sankfinder.notifications.SankNotificationHelper.showRoundCallNotification(
                            getApplication(),
                            sender,
                            msg.content
                        )
                    }
                }

                "drinks_updated" -> {
                    val uid = json.optString("userId")
                    val name = json.optString("name")
                    val count = json.optInt("drinksCount", 0)

                    _members.value = _members.value.map { m ->
                        if (m.id == uid) m.copy(drinksCount = count) else m
                    }
                    if (uid != myUserId) {
                        _bannerAlert.value = "$name ima zdaj $count pijač."
                    }
                }

                "eta_alert" -> {
                    val name = json.optString("name")
                    val lokal = json.optString("targetLokal")
                    val mins = json.optInt("etaMinutes")
                    _bannerAlert.value = "$name: Pridem v $lokal čez ~$mins min."
                }

                "room_closed_by_admin" -> {
                    leaveSquad()
                    _errorMessage.value = "Sobo je administrator zaprl."
                }

                "message_deleted" -> {
                    val msgId = json.optLong("id", -1L)
                    if (msgId != -1L) {
                        _messages.value = _messages.value.filterNot { it.id == msgId }
                    }
                }

                "admin_broadcast" -> {
                    val title = json.optString("title", "Obvestilo uprave")
                    val msgText = json.optString("message", "")
                    if (msgText.isNotBlank()) {
                        _bannerAlert.value = "$title: $msgText"
                    }
                }
            }
        }
    }

    /**
     * Pošlji običajno chat sporočilo.
     */
    fun sendMessage(text: String) {
        val trimmed = text.trim()
        if (trimmed.isNotBlank() && _activeRoom.value != null) {
            repository.sendChatMessage(trimmed, "text")
        }
    }

    /**
     * Pošlji hitro akcijo (npr. "Naročil rundo!").
     */
    fun sendQuickAction(text: String, type: String = "quick") {
        if (_activeRoom.value != null) {
            repository.sendChatMessage(text, type)
        }
    }

    /**
     * Posodobi število pijač (+1 ali -1).
     */
    fun incrementDrinks() {
        val myCurrent = _members.value.find { it.id == myUserId }?.drinksCount ?: 0
        val newCount = myCurrent + 1
        _members.value = _members.value.map { m ->
            if (m.id == myUserId) m.copy(drinksCount = newCount) else m
        }
        repository.sendDrinkUpdate(1)
    }

    fun decrementDrinks() {
        val myCurrent = _members.value.find { it.id == myUserId }?.drinksCount ?: 0
        if (myCurrent > 0) {
            val newCount = myCurrent - 1
            _members.value = _members.value.map { m ->
                if (m.id == myUserId) m.copy(drinksCount = newCount) else m
            }
            repository.sendDrinkUpdate(-1)
        }
    }

    /**
     * Pošlji predviden čas prihoda.
     */
    fun sendEta(targetName: String, minutes: Int) {
        repository.sendEtaAlert(targetName, minutes)
        sendQuickAction("Sem na poti v $targetName, pridem čez ~$minutes min!", "eta")
    }

    /**
     * Posodobi mojo GPS lokacijo in jo periodično oddaj klapi (vsaj 5s razmika ali premik > 5m).
     */
    fun updateMyLocation(lat: Double, lon: Double) {
        lastSentLat = lat
        lastSentLon = lon
        val now = System.currentTimeMillis()

        if (_activeRoom.value != null && _isConnected.value) {
            if (now - lastSentLocTime > 6000) { // vsakih 6 sekund
                lastSentLocTime = now
                repository.sendLocationUpdate(lat, lon)
            }
        }
    }

    /**
     * Zapusti trenutno klapo in prekini WebSocket.
     */
    fun leaveSquad() {
        repository.disconnectWebSocket()
        _activeRoom.value = null
        _members.value = emptyList()
        _messages.value = emptyList()
        _isConnected.value = false
    }

    override fun onCleared() {
        super.onCleared()
        repository.disconnectWebSocket()
    }
}

package com.example.sankfinder.data

/**
 * Podatkovni modeli za Pivsko Klapo (Squad Chat & Live Lokacija).
 */

data class SquadRoom(
    val id: String,
    val code: String,
    val name: String
)

data class SquadMember(
    val id: String,
    val roomCode: String,
    val name: String,
    val lat: Double?,
    val lon: Double?,
    val drinksCount: Int,
    val lastSeen: String?
)

data class SquadMessage(
    val id: Long,
    val roomCode: String,
    val senderId: String,
    val senderName: String,
    val msgType: String = "text", // "text", "round_call", "eta", "quick"
    val content: String,
    val createdAt: String
)

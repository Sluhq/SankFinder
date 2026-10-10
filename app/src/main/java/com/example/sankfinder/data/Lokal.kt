package com.example.sankfinder.data

import kotlinx.serialization.Serializable

@Serializable
data class Lokal(
    val name: String,
    val address: String,
    val lat: Double,
    val lon: Double,
    val cuisine: String? = null,
    val phone: String? = null,
    val website: String? = null,
    val openingHours: String? = null
)

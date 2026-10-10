package com.example.sankfinder.data

import java.time.LocalDateTime

data class VisitHistory(
    val lokal: Lokal,
    val visitedAt: LocalDateTime,
    val drinks: Int = 0,
    val amountSpent: Double = 0.0,
    val rating: Double? = null,
    val note: String? = null
)

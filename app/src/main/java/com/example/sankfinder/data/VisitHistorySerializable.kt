package com.example.sankfinder.data

import kotlinx.serialization.Serializable
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

@Serializable
data class VisitHistorySerializable(
    val lokal: Lokal,
    val visitedAt: String,
    val drinks: Int = 0,
    val amountSpent: Double = 0.0,
    val rating: Double? = null,
    val note: String? = null
) {
    fun toVisitHistory(): VisitHistory {
        return VisitHistory(
            lokal = lokal.copy(),
            visitedAt = LocalDateTime.parse(visitedAt, DateTimeFormatter.ISO_LOCAL_DATE_TIME),
            drinks = drinks,
            amountSpent = amountSpent,
            rating = rating,
            note = note
        )
    }

    companion object {
        fun from(visit: VisitHistory): VisitHistorySerializable {
            return VisitHistorySerializable(
                lokal = visit.lokal.copy(),
                visitedAt = visit.visitedAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                drinks = visit.drinks,
                amountSpent = visit.amountSpent,
                rating = visit.rating,
                note = visit.note
            )
        }
    }
}

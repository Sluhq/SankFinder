package com.example.sankfinder.datastore

import com.example.sankfinder.data.Lokal
import com.example.sankfinder.data.VisitHistory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.time.LocalDateTime

object VisitHistoryManager {

    private val _history = MutableStateFlow<List<VisitHistory>>(emptyList())
    val history: StateFlow<List<VisitHistory>> = _history

    fun addVisit(visit: VisitHistory) {
        _history.value = _history.value + visit
    }

    fun addSimpleVisit(lokal: Lokal) {
        val visit = VisitHistory(lokal = lokal, visitedAt = LocalDateTime.now())
        addVisit(visit)
    }

    fun updateVisit(index: Int, updated: VisitHistory) {
        val current = _history.value.toMutableList()
        if (index in current.indices) {
            current[index] = updated
            _history.value = current
        }
    }

    fun removeVisit(index: Int) {
        val current = _history.value.toMutableList()
        if (index in current.indices) {
            current.removeAt(index)
            _history.value = current
        }
    }

    fun clearHistory() {
        _history.value = emptyList()
    }
}

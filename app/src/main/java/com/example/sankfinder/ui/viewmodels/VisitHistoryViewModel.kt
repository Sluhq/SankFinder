package com.example.sankfinder.ui.viewmodels

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.sankfinder.data.Lokal
import com.example.sankfinder.data.VisitHistory
import com.example.sankfinder.data.VisitHistoryStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.time.LocalDateTime

class VisitHistoryViewModel : ViewModel() {

    private val _history = MutableStateFlow<List<VisitHistory>>(emptyList())
    val history: StateFlow<List<VisitHistory>> = _history

    fun loadFromStorage(context: Context) {
        viewModelScope.launch {
            val loaded = VisitHistoryStore.load(context)
            _history.value = loaded.map { visit ->
                Log.d("VisitDebug", "Naložen obisk: ${visit.lokal.name}, drinks=${visit.drinks}, amount=${visit.amountSpent}, rating=${visit.rating}, note=${visit.note}")
                visit.copy(lokal = visit.lokal.copy())
            }
        }
    }

    fun saveToStorage(context: Context) {
        viewModelScope.launch {
            Log.d("VisitDebug", "Shranjujem ${history.value.size} obiskov...")
            VisitHistoryStore.save(context, history.value.map { visit ->
                Log.d("VisitDebug", "Shranjujem obisk: ${visit.lokal.name}, drinks=${visit.drinks}, amount=${visit.amountSpent}, rating=${visit.rating}, note=${visit.note}")
                visit.copy(
                    lokal = visit.lokal.copy(),
                    drinks = visit.drinks,
                    amountSpent = visit.amountSpent,
                    rating = visit.rating,
                    note = visit.note
                )
            })
        }
    }

    // Vrne true, če je dodajanje uspelo, false če je ocena neveljavna
    fun addVisit(context: Context, visit: VisitHistory): Boolean {
        val rating = visit.rating
        if (rating != null && (rating < 0.0 || rating > 5.0)) {
            return false
        }

        val visitCopy = visit.copy(
            lokal = visit.lokal.copy(),
            drinks = visit.drinks,
            amountSpent = visit.amountSpent,
            rating = rating,
            note = visit.note
        )
        Log.d("VisitDebug", "Dodajam obisk: ${visitCopy.lokal.name}, drinks=${visitCopy.drinks}, amount=${visitCopy.amountSpent}, rating=${visitCopy.rating}, note=${visitCopy.note}")
        _history.value = _history.value + visitCopy
        saveToStorage(context)
        return true
    }

    fun addSimpleVisit(context: Context, lokal: Lokal) {
        val lokalCopy = lokal.copy()

        val visit = VisitHistory(
            lokal = lokalCopy,
            visitedAt = LocalDateTime.now(),
            drinks = 0,
            amountSpent = 0.0,
            rating = null,
            note = null
        )

        Log.d("VisitDebug", "Dodajam preprost obisk: ${lokalCopy.name}")
        addVisit(context, visit)
    }

    /**
     * Updates an existing visit with matching pub name, or adds a new visit if not found.
     * Perfect for scanning receipts where values are updated in history.
     */
    fun addOrUpdateVisit(context: Context, visit: VisitHistory): Boolean {
        val currentList = _history.value.toMutableList()
        // Look for existing visit with matching pub name
        val existingIndex = currentList.indexOfLast {
            it.lokal.name.equals(visit.lokal.name, ignoreCase = true)
        }

        if (existingIndex != -1) {
            val existing = currentList[existingIndex]
            val mergedVisit = existing.copy(
                drinks = if (visit.drinks > 0) visit.drinks else existing.drinks,
                amountSpent = if (visit.amountSpent > 0.0) visit.amountSpent else existing.amountSpent,
                rating = visit.rating ?: existing.rating,
                note = visit.note ?: existing.note,
                visitedAt = visit.visitedAt
            )
            currentList[existingIndex] = mergedVisit
            _history.value = currentList
            saveToStorage(context)
            Log.d("VisitDebug", "Posodobljen obstoječi obisk z računa za: ${visit.lokal.name}")
            return true
        } else {
            return addVisit(context, visit)
        }
    }

    fun updateVisit(context: Context, index: Int, updated: VisitHistory): Boolean {
        val rating = updated.rating
        if (rating != null && (rating < 0.0 || rating > 5.0)) {
            return false
        }

        val updatedCopy = updated.copy(
            lokal = updated.lokal.copy(),
            drinks = updated.drinks,
            amountSpent = updated.amountSpent,
            rating = rating,
            note = updated.note
        )
        Log.d("VisitDebug", "Posodabljam obisk na indexu $index: ${updatedCopy.lokal.name}, drinks=${updatedCopy.drinks}, amount=${updatedCopy.amountSpent}, rating=${updatedCopy.rating}, note=${updatedCopy.note}")
        _history.value = _history.value.toMutableList().also {
            if (index in it.indices) it[index] = updatedCopy
        }
        saveToStorage(context)
        return true
    }

    fun removeVisit(context: Context, index: Int) {
        Log.d("VisitDebug", "Odstranjujem obisk na indexu $index")
        _history.value = _history.value.toMutableList().also {
            if (index in it.indices) it.removeAt(index)
        }
        saveToStorage(context)
    }

    fun clearHistory(context: Context) {
        Log.d("VisitDebug", "Brisanje celotne zgodovine (${_history.value.size} obiskov)")
        _history.value = emptyList()
        saveToStorage(context)
    }
}

package com.example.sankfinder.ui.viewmodels

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class DrunkViewModel(private val savedStateHandle: SavedStateHandle) : ViewModel() {

    companion object {
        private const val KEY_DRINKS = "drunk_meter_drinks"
        private const val KEY_WATER = "drunk_meter_water"
        private const val DEFAULT_MAX_DRINKS = 10
    }

    private val _drinks = MutableStateFlow(savedStateHandle.get<Int>(KEY_DRINKS) ?: 0)
    val drinks: StateFlow<Int> = _drinks.asStateFlow()

    private val _water = MutableStateFlow(savedStateHandle.get<Int>(KEY_WATER) ?: 0)
    val water: StateFlow<Int> = _water.asStateFlow()

    // Dynamically expand max capacity if drinks go beyond 10 so krigel doesn't cap abruptly
    val maxDrinks: Int
        get() = maxOf(DEFAULT_MAX_DRINKS, _drinks.value + 2)

    fun addDrink() {
        _drinks.update { current ->
            val next = current + 1
            savedStateHandle[KEY_DRINKS] = next
            next
        }
    }

    fun removeDrink() {
        _drinks.update { current ->
            val next = (current - 1).coerceAtLeast(0)
            savedStateHandle[KEY_DRINKS] = next
            next
        }
    }

    fun addWater() {
        _water.update { current ->
            val next = current + 1
            savedStateHandle[KEY_WATER] = next
            next
        }
    }

    fun removeWater() {
        _water.update { current ->
            val next = (current - 1).coerceAtLeast(0)
            savedStateHandle[KEY_WATER] = next
            next
        }
    }

    fun reset() {
        _drinks.value = 0
        savedStateHandle[KEY_DRINKS] = 0
        _water.value = 0
        savedStateHandle[KEY_WATER] = 0
    }
}
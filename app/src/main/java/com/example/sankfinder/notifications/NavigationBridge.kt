package com.example.sankfinder.notifications

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Most za prenos dogodkov med obvestili (Notification Action) in navigacijskim ViewModelom.
 */
object NavigationBridge {
    private val _stopNavigationFlow = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val stopNavigationFlow: SharedFlow<Unit> = _stopNavigationFlow.asSharedFlow()

    fun requestStopNavigation() {
        _stopNavigationFlow.tryEmit(Unit)
    }
}

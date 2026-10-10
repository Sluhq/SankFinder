package com.example.sankfinder.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SankNotificationReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_STOP_SESSION = "com.example.sankfinder.ACTION_STOP_SESSION"
        const val ACTION_STOP_NAVIGATION = "com.example.sankfinder.ACTION_STOP_NAVIGATION"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_STOP_SESSION -> {
                SankNotificationHelper.dismissNotification(context)
            }
            ACTION_STOP_NAVIGATION -> {
                SankNotificationHelper.dismissNavigationNotification(context)
                NavigationBridge.requestStopNavigation()
            }
        }
    }
}

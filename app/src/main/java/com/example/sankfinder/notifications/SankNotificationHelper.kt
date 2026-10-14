package com.example.sankfinder.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.sankfinder.MainActivity

object SankNotificationHelper {

    private const val CHANNEL_ID = "sankfinder_live_session_v2"
    private const val CHANNEL_NAME = "ŠankFinder – Aktivni obiski"
    const val NOTIFICATION_ID = 2026

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH // High importance ensures expanded display
            ).apply {
                description = "Prikazuje aktivni obisk lokala in spremlja čas obiska"
                enableVibration(false)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.createNotificationChannel(channel)
        }
    }

    /**
     * Show live ongoing session notification with chronometer (Google Maps & Apple Live Activity style)
     */
    fun showOngoingPubSessionNotification(
        context: Context,
        pubName: String,
        pubAddress: String
    ) {
        createNotificationChannel(context)

        val appIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val appPendingIntent = PendingIntent.getActivity(
            context,
            0,
            appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(context, SankNotificationReceiver::class.java).apply {
            action = SankNotificationReceiver.ACTION_STOP_SESSION
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("ŠankFinder: $pubName")
            .setContentText("Aktivni obisk • $pubAddress")
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION) // Same category as Google Maps navigation
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(appPendingIntent)
            .setOngoing(true) // Stays in notification tray/lockscreen
            .setUsesChronometer(true) // Interactive live timer showing elapsed time
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setAutoCancel(false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Končaj obisk",
                stopPendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_view,
                "Odpri aplikacijo",
                appPendingIntent
            )
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("ŠankFinder: $pubName")
                    .setSummaryText("Aktivni obisk")
                    .bigText("Lokal: $pubName\nNaslov: $pubAddress\nČas obiska teče v živo.")
            )

        try {
            val manager = NotificationManagerCompat.from(context)
            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (e: SecurityException) {
            println("Obvestilo ni bilo poslano zaradi dovoljenj: ${e.message}")
        }
    }

    fun dismissNotification(context: Context) {
        try {
            val manager = NotificationManagerCompat.from(context)
            manager.cancel(NOTIFICATION_ID)
        } catch (e: Exception) {
            println("Napaka pri zapiranju obvestila: ${e.message}")
        }
    }

    const val NAV_NOTIFICATION_ID = 2027
    private const val NAV_CHANNEL_ID = "sankfinder_live_navigation_v2"
    private const val NAV_CHANNEL_NAME = "ŠankFinder – Navigacija v živo"

    fun createNavNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NAV_CHANNEL_ID,
                NAV_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // Nemoteče obvestilo brez vsiljivega pojavljanja čez zaslon
            ).apply {
                description = "Prikazuje navodila za pot, ETA in napredek hoje do šanka"
                enableVibration(false)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.createNotificationChannel(channel)
        }
    }

    /**
     * Interaktivno obvestilo o navigaciji v živo (Google Maps slog s potekom, ETA, veliko smerno puščico in gumbom za zaključek)
     */
    fun showLiveNavigationNotification(
        context: Context,
        maneuverText: String,
        distanceToNext: Double,
        remainingMeters: Double,
        remainingSeconds: Double,
        destLokalName: String,
        totalDistance: Double,
        modifier: String? = null,
        type: String? = null
    ) {
        createNavNotificationChannel(context)

        val appIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val appPendingIntent = PendingIntent.getActivity(
            context,
            10,
            appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(context, SankNotificationReceiver::class.java).apply {
            action = SankNotificationReceiver.ACTION_STOP_NAVIGATION
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            11,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val eta = com.example.sankfinder.ui.map.MapMarkerUtils.formatEta(remainingSeconds)
        val distNext = com.example.sankfinder.ui.map.MapMarkerUtils.formatDistance(distanceToNext)
        val distTotal = com.example.sankfinder.ui.map.MapMarkerUtils.formatDistance(remainingMeters)
        val durTotal = com.example.sankfinder.ui.map.MapMarkerUtils.formatDuration(remainingSeconds)

        val progress = if (totalDistance > 0) {
            (((totalDistance - remainingMeters) / totalDistance) * 100).toInt().coerceIn(0, 100)
        } else {
            0
        }

        val title = if (distanceToNext > 5) "Čez $distNext: $maneuverText" else maneuverText
        val subheader = "ŠankFinder • Prihod $eta"
        val body = "Cilj: $destLokalName • Še $distTotal ($durTotal)"

        val largeManeuverIcon = com.example.sankfinder.ui.map.MapMarkerUtils.createNotificationManeuverBitmap(
            context,
            modifier,
            type
        )

        val builder = NotificationCompat.Builder(context, NAV_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_directions)
            .setLargeIcon(largeManeuverIcon) // Velika smerna puščica na desni kot v Google Maps (slika 3)
            .setContentTitle(title)
            .setContentText(body)
            .setSubText(subheader)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setPriority(NotificationCompat.PRIORITY_LOW) // Brez nadležnega spustnega okna
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(appPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setProgress(100, progress, false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Končaj navigacijo",
                stopPendingIntent
            )
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(title)
                    .setSummaryText(subheader)
                    .bigText("$body\nNapredek poti: $progress %")
            )

        try {
            val manager = NotificationManagerCompat.from(context)
            manager.notify(NAV_NOTIFICATION_ID, builder.build())
        } catch (e: SecurityException) {
            println("Navigacijsko obvestilo ni bilo poslano zaradi dovoljenj: ${e.message}")
        }
    }

    fun dismissNavigationNotification(context: Context) {
        try {
            val manager = NotificationManagerCompat.from(context)
            manager.cancel(NAV_NOTIFICATION_ID)
        } catch (e: Exception) {
            println("Napaka pri zapiranju navigacijskega obvestila: ${e.message}")
        }
    }

    // 3. GLOBALNA POTISNA OBVESTILA ZA CELOTNO APLIKACIJO (SISTEMSKA OBVESTILA V VRSTICI)
    const val GLOBAL_ANNOUNCEMENT_CHANNEL_ID = "sankfinder_global_announcements_v1"
    private const val GLOBAL_ANNOUNCEMENT_CHANNEL_NAME = "ŠankFinder – Obvestila uprave"

    fun createGlobalAnnouncementChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                GLOBAL_ANNOUNCEMENT_CHANNEL_ID,
                GLOBAL_ANNOUNCEMENT_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Pomembna obvestila in novice za celotno aplikacijo ŠankFinder"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 150, 300)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.createNotificationChannel(channel)
        }
    }

    fun showGlobalAppNotification(
        context: Context,
        title: String,
        message: String,
        notificationId: Int = (System.currentTimeMillis() % 100000).toInt()
    ) {
        createGlobalAnnouncementChannel(context)

        val appIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val appPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, GLOBAL_ANNOUNCEMENT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(appPendingIntent)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(title)
                    .bigText(message)
            )

        try {
            val manager = NotificationManagerCompat.from(context)
            manager.notify(notificationId, builder.build())
        } catch (e: SecurityException) {
            println("Globalno obvestilo ni bilo prikazano zaradi dovoljenj: ${e.message}")
        }
    }

    /**
     * Potisno obvestilo na vrhu zaslona, ko član klape pritisne gumb 'Jaz častim rundo'
     */
    fun showRoundCallNotification(
        context: Context,
        senderName: String,
        messageText: String
    ) {
        showGlobalAppNotification(
            context = context,
            title = "Pivska Klapa: $senderName časti rundo!",
            message = if (messageText.isNotBlank()) messageText else "Naročil sem novo rundo za celo mizo! Na zdravje!",
            notificationId = 3030
        )
    }
}


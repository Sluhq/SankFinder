package com.example.sankfinder

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.navigation.compose.rememberNavController
import com.example.sankfinder.datastore.ThemeDataStore
import com.example.sankfinder.location.LocationManager
import androidx.compose.runtime.setValue
import androidx.compose.material.icons.filled.Close
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.sankfinder.ui.navigation.AppNavHost
import com.example.sankfinder.ui.theme.AppTheme
import com.example.compose.BeerGold
import com.example.compose.DrajvGreen

class MainActivity : ComponentActivity() {

    private lateinit var locationManager: LocationManager
    private lateinit var themeDataStore: ThemeDataStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        locationManager = LocationManager(this)
        themeDataStore = ThemeDataStore(this)
        locationManager.zahtevajDovoljenjeLokacije()

        // OSMDroid konfiguracija za predpomnjenje zemljevidov in stabilno delovanje
        val osmdroidConfig = org.osmdroid.config.Configuration.getInstance()
        val customUserAgent = "SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)"
        osmdroidConfig.userAgentValue = customUserAgent
        osmdroidConfig.userAgentHttpHeader = "User-Agent" // Mora biti ime HTTP glave ('User-Agent'), NE vrednost!

        // Uporaba internega predpomnilnika prepreči FUSE/SELinux ioctl napake na Android 11+
        val osmdroidBasePath = java.io.File(cacheDir, "osmdroid").apply { mkdirs() }
        val osmdroidTileCache = java.io.File(osmdroidBasePath, "tiles").apply { mkdirs() }
        osmdroidConfig.osmdroidBasePath = osmdroidBasePath
        osmdroidConfig.osmdroidTileCache = osmdroidTileCache
        osmdroidConfig.save(this, getSharedPreferences("osmdroid", MODE_PRIVATE))

        // Počisti morebitne stare neuspešne/blokirane ploščice
        try {
            val mapnikCache = java.io.File(osmdroidTileCache, "Mapnik")
            if (mapnikCache.exists()) mapnikCache.deleteRecursively()
            // Če so se predhodno shranili neveljavni 400 Bad Request odgovori, jih počistimo za svež prenos
            val cartoCache = java.io.File(osmdroidTileCache, "CartoVoyager")
            if (cartoCache.exists()) cartoCache.deleteRecursively()
            // Počisti tudi morebitni stari FUSE predpomnilnik na zunanjem pomnilniku
            getExternalFilesDir(null)?.let { externalDir ->
                val oldExtCache = java.io.File(externalDir, "osmdroid")
                if (oldExtCache.exists()) oldExtCache.deleteRecursively()
            }
        } catch (_: Exception) {}

        org.osmdroid.tileprovider.tilesource.TileSourceFactory.addTileSource(com.example.sankfinder.ui.map.MapMarkerUtils.CARTO_VOYAGER)

        // Zahtevaj dovoljenje za obvestila na Android 13+ (Tiramisu)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }

        // Zagon globalne povezave za celotno aplikacijo
        com.example.sankfinder.network.GlobalSyncManager.init(this)

        setContent {
            val navController = rememberNavController()
            val isDarkTheme by themeDataStore.isDarkTheme.collectAsState(initial = false)

            // Poslušaj globalna potisna obvestila medtem ko je aplikacija odprta
            var inAppAlert by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<com.example.sankfinder.network.PushNotificationEvent?>(null) }
            androidx.compose.runtime.LaunchedEffect(Unit) {
                com.example.sankfinder.network.GlobalSyncManager.pushEvents.collect { event ->
                    inAppAlert = event
                }
            }

            val currentMotd by com.example.sankfinder.network.GlobalSyncManager.motd.collectAsState()
            var dismissedMotd by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<String?>(null) }

            AppTheme(darkTheme = isDarkTheme) {
                androidx.compose.foundation.layout.Box(modifier = androidx.compose.ui.Modifier.fillMaxSize()) {
                    AppNavHost(
                        navController = navController,
                        themeDataStore = themeDataStore
                    )

                    // Pasica za Sporočilo Dneva (MOTD)
                    val activeMotd = currentMotd
                    if (!activeMotd.isNullOrBlank() && activeMotd != dismissedMotd) {
                        androidx.compose.animation.AnimatedVisibility(
                            visible = true,
                            enter = androidx.compose.animation.slideInVertically() + androidx.compose.animation.fadeIn(),
                            exit = androidx.compose.animation.slideOutVertically() + androidx.compose.animation.fadeOut(),
                            modifier = androidx.compose.ui.Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = if (inAppAlert != null) 90.dp else 24.dp)
                                .align(androidx.compose.ui.Alignment.TopCenter)
                        ) {
                            androidx.compose.material3.Surface(
                                shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp),
                                color = androidx.compose.material3.MaterialTheme.colorScheme.surfaceVariant,
                                tonalElevation = 8.dp,
                                shadowElevation = 8.dp,
                                border = androidx.compose.foundation.BorderStroke(1.dp, DrajvGreen.copy(alpha = 0.8f))
                            ) {
                                androidx.compose.foundation.layout.Row(
                                    modifier = androidx.compose.ui.Modifier.padding(14.dp),
                                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                                ) {
                                    androidx.compose.foundation.layout.Column(modifier = androidx.compose.ui.Modifier.weight(1f)) {
                                        androidx.compose.material3.Text(
                                            text = "Sporočilo dneva",
                                            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                                            fontSize = 13.5.sp,
                                            color = DrajvGreen
                                        )
                                        androidx.compose.material3.Text(
                                            text = activeMotd,
                                            fontSize = 12.5.sp,
                                            color = androidx.compose.material3.MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                    androidx.compose.material3.IconButton(onClick = { dismissedMotd = activeMotd }) {
                                        androidx.compose.material3.Icon(
                                            androidx.compose.material.icons.Icons.Default.Close,
                                            contentDescription = "Zapri",
                                            tint = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Vizualna pasica za obvestilo uprave na vrhu zaslona
                    inAppAlert?.let { alert ->
                        androidx.compose.animation.AnimatedVisibility(
                            visible = true,
                            enter = androidx.compose.animation.slideInVertically() + androidx.compose.animation.fadeIn(),
                            exit = androidx.compose.animation.slideOutVertically() + androidx.compose.animation.fadeOut(),
                            modifier = androidx.compose.ui.Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 24.dp)
                                .align(androidx.compose.ui.Alignment.TopCenter)
                        ) {
                            androidx.compose.material3.Surface(
                                shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp),
                                color = androidx.compose.material3.MaterialTheme.colorScheme.surfaceVariant,
                                tonalElevation = 8.dp,
                                shadowElevation = 8.dp,
                                border = androidx.compose.foundation.BorderStroke(1.dp, BeerGold.copy(alpha = 0.6f))
                            ) {
                                androidx.compose.foundation.layout.Row(
                                    modifier = androidx.compose.ui.Modifier.padding(14.dp),
                                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                                ) {
                                    androidx.compose.foundation.layout.Column(modifier = androidx.compose.ui.Modifier.weight(1f)) {
                                        androidx.compose.material3.Text(
                                            text = alert.title,
                                            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                                            fontSize = 14.sp,
                                            color = BeerGold
                                        )
                                        androidx.compose.material3.Text(
                                            text = alert.message,
                                            fontSize = 12.5.sp,
                                            color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    androidx.compose.material3.IconButton(onClick = { inAppAlert = null }) {
                                        androidx.compose.material3.Icon(
                                            androidx.compose.material.icons.Icons.Default.Close,
                                            contentDescription = "Zapri",
                                            tint = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

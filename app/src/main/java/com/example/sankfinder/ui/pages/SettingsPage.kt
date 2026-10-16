package com.example.sankfinder.ui.pages

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.example.compose.DrajvGreen
import com.example.compose.DrajvRed
import com.example.sankfinder.datastore.ThemeDataStore
import com.example.sankfinder.network.GlobalSyncManager
import com.example.sankfinder.ui.components.AppTopBar
import com.example.sankfinder.ui.navigation.BottomNavBar
import com.example.sankfinder.ui.navigation.Routes
import com.example.sankfinder.ui.viewmodels.LokalViewModel
import com.google.android.gms.location.LocationServices
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@SuppressLint("MissingPermission")
@Composable
fun SettingsPage(
    navController: NavController,
    themeDataStore: ThemeDataStore
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val isDarkTheme by themeDataStore.isDarkTheme.collectAsState(initial = false)

    val isOutdated by GlobalSyncManager.isOutdated.collectAsState()
    val latestVersion by GlobalSyncManager.latestVersion.collectAsState()
    val versionNotes by GlobalSyncManager.versionNotes.collectAsState()
    val currentVersion = try { com.example.sankfinder.BuildConfig.VERSION_NAME } catch (e: Exception) { "1.2.0" }

    LaunchedEffect(Unit) {
        GlobalSyncManager.fetchInitialConfig()
    }

    val savedRadiusMeters by themeDataStore.searchRadius.collectAsState(initial = 2000)
    var selectedRadiusKm by remember { mutableIntStateOf(savedRadiusMeters / 1000) }

    LaunchedEffect(savedRadiusMeters) {
        selectedRadiusKm = savedRadiusMeters / 1000
    }

    val savedSoundAlerts by themeDataStore.soundAlerts.collectAsState(initial = true)
    val savedNotifications by themeDataStore.pushNotifications.collectAsState(initial = true)
    val savedSafeTrip by themeDataStore.safeTrip.collectAsState(initial = true)
    val savedLokalLimit by themeDataStore.lokalLimit.collectAsState(initial = 20)

    var soundAlerts by remember { mutableStateOf(true) }
    var pushNotifications by remember { mutableStateOf(true) }
    var safeTripAlert by remember { mutableStateOf(true) }
    var selectedLokalLimit by remember { mutableIntStateOf(20) }
    var showCustomLimitDialog by remember { mutableStateOf(false) }
    var customLimitInput by remember { mutableStateOf("") }

    LaunchedEffect(savedSoundAlerts, savedNotifications, savedSafeTrip, savedLokalLimit) {
        soundAlerts = savedSoundAlerts
        pushNotifications = savedNotifications
        safeTripAlert = savedSafeTrip
        selectedLokalLimit = savedLokalLimit
    }

    // Dialog state
    var showAboutDialog by remember { mutableStateOf(false) }

    // Geoapify test state
    val lokalViewModel: LokalViewModel = viewModel()
    var isTestingApi by remember { mutableStateOf(false) }
    var apiStatusText by remember { mutableStateOf("Povezava z Geoapify bazo deluje.") }
    var isApiConnected by remember { mutableStateOf(true) }

    // Permissions check
    var isLocationPermissionGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        )
    }

    var isCoarseGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        )
    }

    var isCameraGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED
        )
    }

    val fusedLocationClient = remember { LocationServices.getFusedLocationProviderClient(context) }
    var userLat by remember { mutableStateOf<Double?>(null) }
    var userLon by remember { mutableStateOf<Double?>(null) }

    val refreshDiagnostics = {
        isLocationPermissionGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        isCoarseGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        isCameraGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        fusedLocationClient.lastLocation.addOnSuccessListener { loc ->
            if (loc != null) {
                userLat = loc.latitude
                userLon = loc.longitude
            }
        }
    }

    LaunchedEffect(Unit) {
        refreshDiagnostics()
    }

    // Samodejno osveži diagnostiko ob vrnitvi v aplikacijo iz nastavitev telefona
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                refreshDiagnostics()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    val openAppSettings = {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    Scaffold(
        topBar = {
            AppTopBar(
                title = "Nastavitve",
                currentRoute = Routes.SETTINGS,
                onNavigationClick = { navController.popBackStack() }
            )
        },
        bottomBar = { BottomNavBar(navController = navController) }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 18.dp, vertical = 12.dp)
        ) {
            // OPOZORILO: ZASTARELA VERZIJA APLIKACIJE (če strežnik poroča o novejši verziji)
            if (isOutdated) {
                item {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 14.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.22f)
                        ),
                        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.error),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Warning,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(28.dp)
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = "Opozorilo: Stara različica aplikacije",
                                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                                    color = MaterialTheme.colorScheme.error
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = "Uporabljate v$currentVersion, na voljo je nova posodobitev v${latestVersion ?: "1.2.0"}. ${versionNotes ?: ""} Prosimo posodobite aplikacijo.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }

            // TOP ITEM: Zvočna opozorila (as seen in DRAJV screenshot)
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Zvočna opozorila",
                            style = MaterialTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 16.sp
                            )
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = "Opozorilo ob povišani stopnji alkohola",
                            style = MaterialTheme.typography.bodyMedium.copy(
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                fontSize = 13.sp
                            )
                        )
                    }

                    Switch(
                        checked = soundAlerts,
                        onCheckedChange = { enabled ->
                            soundAlerts = enabled
                            coroutineScope.launch { themeDataStore.setSoundAlerts(enabled) }
                        },
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = Color.White,
                            checkedTrackColor = DrajvRed,
                            uncheckedThumbColor = MaterialTheme.colorScheme.outline,
                            uncheckedTrackColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                    )
                }

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                    thickness = 0.5.dp
                )

                Spacer(modifier = Modifier.height(18.dp))
            }

            // SECTION HEADER: ŠANKFINDER diagnostika – dovoljenja aplikacije (DRAJV style)
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "ŠANKFINDER diagnostika – dovoljenja aplikacije",
                            style = MaterialTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp
                            ),
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Za nemoteno delovanje poskrbite, da so vsa dovoljenja odobrena.",
                            style = MaterialTheme.typography.bodySmall.copy(
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                fontSize = 13.sp
                            )
                        )
                    }

                    IconButton(
                        onClick = { refreshDiagnostics() },
                        modifier = Modifier.size(38.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Osveži diagnostiko",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(22.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(14.dp))
            }

            // DIAGNOSTICS CARD (Grouped items with green checkmarks)
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                    )
                ) {
                    Column {
                        // 1. Lokacija
                        DiagnosticItem(
                            isApproved = isLocationPermissionGranted,
                            title = "Lokacija",
                            subtitle = if (isLocationPermissionGranted)
                                "Dostop do lokacije naprave omogočen."
                            else
                                "Lokacija ni odobrena. Kliknite za vklop.",
                            onClick = openAppSettings
                        )

                        HorizontalDivider(
                            modifier = Modifier.padding(start = 52.dp),
                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f),
                            thickness = 0.5.dp
                        )

                        // 2. Mobilni senzorji / GPS
                        DiagnosticItem(
                            isApproved = isLocationPermissionGranted || isCoarseGranted,
                            title = "Mobilni senzorji & GPS",
                            subtitle = if (isLocationPermissionGranted)
                                "Dostop do visoke natančnosti GPS je omogočen."
                            else
                                "Dostop do GPS senzorjev je omejen.",
                            onClick = openAppSettings
                        )

                        HorizontalDivider(
                            modifier = Modifier.padding(start = 52.dp),
                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f),
                            thickness = 0.5.dp
                        )

                        // 3. Kamera (za skeniranje računov)
                        DiagnosticItem(
                            isApproved = isCameraGranted,
                            title = "Kamera (Skeniranje računov)",
                            subtitle = if (isCameraGranted)
                                "Dostop do kamere za branje računov in QR kod omogočen."
                            else
                                "Kamera ni odobrena. Kliknite za odobritev.",
                            onClick = openAppSettings
                        )

                        HorizontalDivider(
                            modifier = Modifier.padding(start = 52.dp),
                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f),
                            thickness = 0.5.dp
                        )

                        // 4. Različica aplikacije
                        DiagnosticItem(
                            isApproved = !isOutdated,
                            title = "Različica aplikacije",
                            subtitle = if (isOutdated)
                                "Zastarela različica (v$currentVersion). Na voljo je nova različica v${latestVersion ?: "1.2.0"}!"
                            else
                                "Aplikacija je posodobljena. Različica $currentVersion (Najnovejša).",
                            onClick = { showAboutDialog = true }
                        )

                        HorizontalDivider(
                            modifier = Modifier.padding(start = 52.dp),
                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f),
                            thickness = 0.5.dp
                        )

                        // 5. Strežnik Geoapify / API
                        DiagnosticItem(
                            isApproved = isApiConnected,
                            title = "Povezava s strežnikom lokalov",
                            subtitle = if (isTestingApi) "Preverjam povezavo s strežnikom..." else apiStatusText,
                            trailingContent = {
                                if (isTestingApi) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(18.dp),
                                        strokeWidth = 2.dp,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                } else {
                                    Icon(
                                        imageVector = Icons.Default.Refresh,
                                        contentDescription = "Testiraj",
                                        tint = DrajvRed,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            },
                            onClick = {
                                if (!isTestingApi) {
                                    coroutineScope.launch {
                                        isTestingApi = true
                                        val lat = userLat ?: 46.056946
                                        val lon = userLon ?: 14.505751
                                        lokalViewModel.fetchLokali(lat, lon, selectedRadiusKm * 1000)
                                        delay(1200)
                                        val count = lokalViewModel.lokali.value.size
                                        if (count > 0) {
                                            isApiConnected = true
                                            apiStatusText = "Povezava deluje! V radiju ${selectedRadiusKm}km najdenih $count lokalov."
                                        } else {
                                            apiStatusText = "Povezava vzpostavljena (0 lokalov v neposrednem radiju)."
                                        }
                                        isTestingApi = false
                                    }
                                }
                            }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))
            }

            // OTHER SETTINGS - TOGGLES (DRAJV red switch style)
            item {
                Text(
                    text = "Dodatne možnosti",
                    style = MaterialTheme.typography.titleMedium.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    ),
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.height(8.dp))

                // Potisna obvestila
                SettingToggleRow(
                    title = "Potisna obvestila",
                    subtitle = "Obvestila o varni poti in spremljanje obiska na zaklenjenem zaslonu",
                    checked = pushNotifications,
                    onCheckedChange = { enabled ->
                        pushNotifications = enabled
                        coroutineScope.launch { themeDataStore.setPushNotifications(enabled) }
                    }
                )

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f),
                    thickness = 0.5.dp
                )

                // Varna pot domov
                SettingToggleRow(
                    title = "Potrditev ali zavrnitev varne poti",
                    subtitle = "Samodejni predlog klica taksija ob doseženem limitu pijač",
                    checked = safeTripAlert,
                    onCheckedChange = { enabled ->
                        safeTripAlert = enabled
                        coroutineScope.launch { themeDataStore.setSafeTrip(enabled) }
                    }
                )

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f),
                    thickness = 0.5.dp
                )


                // Temna tema
                SettingToggleRow(
                    title = "Nočni način šanka (Temna tema)",
                    subtitle = "Privlačen temen videz za večerne izhode",
                    checked = isDarkTheme,
                    onCheckedChange = { enabled ->
                        coroutineScope.launch {
                            themeDataStore.setDarkTheme(enabled)
                        }
                    }
                )

                Spacer(modifier = Modifier.height(20.dp))
            }

            // RADIJ ISKANJA (Search Radius selector - connected to DataStore)
            item {
                Text(
                    text = "Radij iskanja lokalov: ${selectedRadiusKm} km",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold)
                )
                Text(
                    text = "Določa območje za iskanje šankov okoli vaše lokacije (${selectedRadiusKm * 1000} metrov)",
                    style = MaterialTheme.typography.bodySmall.copy(
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                )
                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    val radiusOptions = listOf(1 to "1 km", 2 to "2 km", 3 to "3 km", 5 to "5 km")
                    radiusOptions.forEach { (km, label) ->
                        FilterChip(
                            selected = selectedRadiusKm == km,
                            onClick = {
                                selectedRadiusKm = km
                                coroutineScope.launch {
                                    themeDataStore.setSearchRadius(km * 1000)
                                }
                            },
                            label = { Text(label, fontWeight = if (selectedRadiusKm == km) FontWeight.Bold else FontWeight.Normal) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))
            }

            // ŠTEVILO PRIKAZANIH LOKALOV (10, 25, 50 ali po meri)
            item {
                Text(
                    text = "Število prikazanih lokalov: $selectedLokalLimit",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold)
                )
                Text(
                    text = "Določa, koliko najbližjih šankov se naloži in prikaže na zemljevidu ter seznamu",
                    style = MaterialTheme.typography.bodySmall.copy(
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                )
                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    val limitOptions = listOf(10, 25, 50)
                    limitOptions.forEach { count ->
                        FilterChip(
                            selected = selectedLokalLimit == count,
                            onClick = {
                                selectedLokalLimit = count
                                lokalViewModel.setPreferredLimit(count)
                                coroutineScope.launch {
                                    themeDataStore.setLokalLimit(count)
                                }
                            },
                            label = { Text("$count", fontWeight = if (selectedLokalLimit == count) FontWeight.Bold else FontWeight.Normal) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        )
                    }

                    val isCustom = selectedLokalLimit !in listOf(10, 25, 50)
                    FilterChip(
                        selected = isCustom,
                        onClick = {
                            customLimitInput = selectedLokalLimit.toString()
                            showCustomLimitDialog = true
                        },
                        label = { Text(if (isCustom) "Po meri ($selectedLokalLimit)" else "Po meri...", fontWeight = if (isCustom) FontWeight.Bold else FontWeight.Normal) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))
            }

            // O APLIKACIJI BUTTON
            item {
                Button(
                    onClick = { showAboutDialog = true },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = MaterialTheme.colorScheme.onSurface
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("O aplikaciji ŠankFinder")
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }

    if (showAboutDialog) {
        AlertDialog(
            onDismissRequest = { showAboutDialog = false },
            confirmButton = {
                TextButton(onClick = { showAboutDialog = false }) {
                    Text("V redu", color = MaterialTheme.colorScheme.primary)
                }
            },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("ŠankFinder")
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        "Različica: $currentVersion (Zadnja na strežniku: ${latestVersion ?: "1.2.0"})",
                        fontWeight = FontWeight.SemiBold
                    )
                    if (isOutdated) {
                        Text(
                            "Opozorilo: Vaša različica je zastarela! Prosimo posodobite aplikacijo.",
                            color = MaterialTheme.colorScheme.error,
                            fontWeight = FontWeight.Bold
                        )
                    } else {
                        Text(
                            "Aplikacija je posodobljena na najnovejšo različico.",
                            color = Color(0xFF10B981),
                            fontWeight = FontWeight.Medium
                        )
                    }
                    Text("Avtor: Sluhq")
                    Text("Namen: Zanesljiv vodnik za žejne popotnike, ki iščejo najboljše šanke v bližini z vgrajenim merilnikom pijač in varno potjo domov.")
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        "© 2026 ŠankFinder Team. Vse pravice pridržane.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        )
    }

    // Dialog za vnos poljubnega števila lokalov (Po meri)
    if (showCustomLimitDialog) {
        AlertDialog(
            onDismissRequest = { showCustomLimitDialog = false },
            title = {
                Text("Poljubno število lokalov", fontWeight = FontWeight.Bold)
            },
            text = {
                Column {
                    Text(
                        "Vnesite število lokalov, ki jih želite prikazati na zemljevidu (med 5 in 100):",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedTextField(
                        value = customLimitInput,
                        onValueChange = { customLimitInput = it.filter { char -> char.isDigit() }.take(3) },
                        label = { Text("Število lokalov (5 - 100)") },
                        singleLine = true,
                        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                            keyboardType = androidx.compose.ui.text.input.KeyboardType.Number
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val parsed = customLimitInput.toIntOrNull()?.coerceIn(5, 100) ?: 20
                        selectedLokalLimit = parsed
                        lokalViewModel.setPreferredLimit(parsed)
                        coroutineScope.launch {
                            themeDataStore.setLokalLimit(parsed)
                        }
                        showCustomLimitDialog = false
                    }
                ) {
                    Text("Potrdi")
                }
            },
            dismissButton = {
                TextButton(onClick = { showCustomLimitDialog = false }) {
                    Text("Prekliči")
                }
            }
        )
    }
}

@Composable
private fun DiagnosticItem(
    isApproved: Boolean,
    title: String,
    subtitle: String,
    trailingContent: (@Composable () -> Unit)? = null,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Status Checkmark / Warning icon
        Box(
            modifier = Modifier.size(28.dp),
            contentAlignment = Alignment.Center
        ) {
            if (isApproved) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Odobreno",
                    tint = DrajvGreen,
                    modifier = Modifier.size(24.dp)
                )
            } else {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Ni odobreno",
                    tint = DrajvRed,
                    modifier = Modifier.size(22.dp)
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Title and description
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontWeight = FontWeight.Medium,
                    fontSize = 15.sp
                ),
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontSize = 12.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            )
        }

        // Red chevron arrow or custom trailing content (like in DRAJV)
        if (trailingContent != null) {
            trailingContent()
        } else {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = "Podrobnosti",
                tint = DrajvRed,
                modifier = Modifier.size(22.dp)
            )
        }
    }
}

@Composable
private fun SettingToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontWeight = FontWeight.Medium,
                    fontSize = 15.sp
                )
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall.copy(
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.5.sp
                )
            )
        }

        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = DrajvRed,
                uncheckedThumbColor = MaterialTheme.colorScheme.outline,
                uncheckedTrackColor = MaterialTheme.colorScheme.surfaceVariant
            )
        )
    }
}


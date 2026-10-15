package com.example.sankfinder.ui.pages

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.location.Location
import android.net.Uri
import android.util.Log
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.BookmarkAdded
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.LocalCafe
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.SuggestionChipDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import com.example.sankfinder.R
import com.example.compose.BeerGold
import com.example.compose.DrajvGreen
import com.example.compose.DrajvRed
import com.example.sankfinder.data.Lokal
import com.example.sankfinder.ui.components.AppTopBar
import com.example.sankfinder.ui.navigation.BottomNavBar
import com.example.sankfinder.ui.navigation.Routes
import com.example.sankfinder.ui.viewmodels.LokalViewModel
import com.example.sankfinder.ui.viewmodels.MapNavigationViewModel
import com.example.sankfinder.ui.viewmodels.VisitHistoryViewModel
import androidx.compose.foundation.layout.PaddingValues
import com.google.accompanist.swiperefresh.SwipeRefresh
import com.google.accompanist.swiperefresh.rememberSwipeRefreshState
import com.google.android.gms.location.LocationServices
import kotlinx.coroutines.launch
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@SuppressLint("MissingPermission")
@Composable
fun MainPage(
    navController: NavHostController,
    viewModel: LokalViewModel = viewModel(),
    mapNavViewModel: MapNavigationViewModel = viewModel(),
    onNavigationClick: () -> Unit = {}
) {
    val historyViewModel: VisitHistoryViewModel = viewModel()
    val lokali by viewModel.lokali.collectAsState()
    val history by historyViewModel.history.collectAsState()
    val warningMessage by viewModel.warningMessage.collectAsState()
    val isRefreshing = remember { mutableStateOf(false) }
    val lastRefreshTime = remember { mutableStateOf<String?>(null) }

    var searchQuery by remember { mutableStateOf("") }
    var selectedCategoryFilter by remember { mutableStateOf("Vsi") }

    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    // Opozorila ob izgubi interneta ali napakah
    LaunchedEffect(warningMessage) {
        warningMessage?.let { msg ->
            snackbarHostState.showSnackbar(msg)
            viewModel.dismissWarning()
        }
    }

    val context = LocalContext.current
    val fusedLocationClient = remember { LocationServices.getFusedLocationProviderClient(context) }

    val themeDataStore = remember { com.example.sankfinder.datastore.ThemeDataStore(context) }
    val searchRadiusMeters by themeDataStore.searchRadius.collectAsState(initial = 2000)
    val savedLokalLimit by themeDataStore.lokalLimit.collectAsState(initial = 20)

    val triggerRefresh = {
        isRefreshing.value = true
        fusedLocationClient.lastLocation.addOnSuccessListener { location: Location? ->
            if (location != null) {
                viewModel.fetchLokali(location.latitude, location.longitude, searchRadiusMeters, savedLokalLimit)
            } else {
                viewModel.fetchLokali(46.056946, 14.505751, searchRadiusMeters, savedLokalLimit) // Center Ljubljana fallback
            }
            isRefreshing.value = false
        }.addOnFailureListener {
            viewModel.fetchLokali(46.056946, 14.505751, searchRadiusMeters, savedLokalLimit)
            isRefreshing.value = false
        }
    }

    LaunchedEffect(lokali) {
        isRefreshing.value = false
        val currentTime = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        lastRefreshTime.value = currentTime
    }

    LaunchedEffect(searchRadiusMeters, savedLokalLimit) {
        viewModel.setPreferredLimit(savedLokalLimit, forceRefresh = false)
        triggerRefresh()
    }

    LaunchedEffect(Unit) {
        historyViewModel.loadFromStorage(context)
    }

    // Filtered Lokali list based on search
    val filteredLokali = remember(lokali, searchQuery) {
        lokali.filter { lokal ->
            searchQuery.isBlank() ||
                    lokal.name.contains(searchQuery, ignoreCase = true) ||
                    lokal.address.contains(searchQuery, ignoreCase = true) ||
                    (lokal.cuisine?.contains(searchQuery, ignoreCase = true) == true)
        }
    }

    var lokalForReceiptScan by remember { mutableStateOf<Lokal?>(null) }

    Scaffold(
        topBar = {
            AppTopBar(
                title = "Lokali v bližini",
                currentRoute = Routes.MAIN,
                onNavigationClick = onNavigationClick,
                actions = {
                    IconButton(onClick = { navController.navigate(Routes.MAIN) }) {
                        Icon(
                            imageVector = Icons.Default.Map,
                            contentDescription = "Zemljevid",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                    IconButton(onClick = { triggerRefresh() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Osveži",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            )
        },
        bottomBar = { BottomNavBar(navController = navController) },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // SEARCH HEADER (No category chips, clean & spacious)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                // Search Field
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text("Išči lokal ali ulico...") },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = "Išči",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    },
                    trailingIcon = {
                        if (searchQuery.isNotEmpty()) {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(Icons.Default.Clear, contentDescription = "Počisti")
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant
                    )
                )

                Spacer(modifier = Modifier.height(6.dp))

                // Location Status & Radius Subheader
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .background(DrajvGreen, CircleShape)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Radij: ${searchRadiusMeters / 1000} km",
                            style = MaterialTheme.typography.labelSmall.copy(
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        )
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        lastRefreshTime.value?.let {
                            Text(
                                text = "Osveženo: $it • ",
                                style = MaterialTheme.typography.labelSmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            )
                        }
                        Text(
                            text = "${filteredLokali.size} lokalov",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        )
                    }
                }
            }


            // LIST OF PUBS
            SwipeRefresh(
                state = rememberSwipeRefreshState(isRefreshing.value),
                onRefresh = { triggerRefresh() },
                modifier = Modifier.fillMaxSize()
            ) {
                if (filteredLokali.isEmpty() && isRefreshing.value) {
                    // Loading State z logotipom ŠankFinder
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(32.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Image(
                            painter = painterResource(id = R.drawable.sankfinder_logo),
                            contentDescription = "ŠankFinder",
                            modifier = Modifier.size(80.dp)
                        )
                        Spacer(modifier = Modifier.height(18.dp))
                        CircularProgressIndicator(
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(36.dp),
                            strokeWidth = 3.5.dp
                        )
                        Spacer(modifier = Modifier.height(14.dp))
                        Text(
                            text = "Nalagam šanke v bližini...",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else if (filteredLokali.isEmpty() && !isRefreshing.value) {
                    // Friendly Empty State
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(32.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.SportsBar,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f),
                            modifier = Modifier.size(64.dp)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "Ni najdenih lokalov",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Poskusite spremeniti iskalni niz ali kliknite gumb Osveži za iskanje novih šankov.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = {
                            searchQuery = ""
                            selectedCategoryFilter = "Vsi"
                            triggerRefresh()
                        }) {
                            Text("Pokaži vse")
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        items(filteredLokali) { lokal ->
                            LokalCard(
                                lokal = lokal,
                                isVisited = history.any { it.lokal.name == lokal.name && it.lokal.address == lokal.address },
                                onCardClick = {
                                    val alreadyVisited = history.any {
                                        it.lokal.name == lokal.name && it.lokal.address == lokal.address
                                    }
                                    if (!alreadyVisited) {
                                        historyViewModel.addSimpleVisit(context, lokal)
                                    }
                                    mapNavViewModel.setSelectedLokal(lokal)
                                    mapNavViewModel.startNavigation(lokal)
                                    navController.navigate(Routes.MAIN) {
                                        launchSingleTop = true
                                    }
                                },
                                onNavigate = {
                                    mapNavViewModel.setSelectedLokal(lokal)
                                    mapNavViewModel.startNavigation(lokal)
                                    navController.navigate(Routes.MAIN) {
                                        launchSingleTop = true
                                    }
                                },
                                onLogVisit = {
                                    historyViewModel.addSimpleVisit(context, lokal)
                                    coroutineScope.launch {
                                        snackbarHostState.showSnackbar("Obisk v '${lokal.name}' zabeležen v zgodovino!")
                                    }
                                },
                                onScanReceipt = {
                                    lokalForReceiptScan = lokal
                                }
                            )
                        }
                        item {
                            Spacer(modifier = Modifier.height(12.dp))
                        }
                    }
                }
            }
        }
    }

    if (lokalForReceiptScan != null) {
        com.example.sankfinder.ui.components.ReceiptScannerDialog(
            initialLokal = lokalForReceiptScan,
            onReceiptScanned = { visit ->
                historyViewModel.addOrUpdateVisit(context, visit)
                val pub = visit.lokal.name
                lokalForReceiptScan = null
                coroutineScope.launch {
                    snackbarHostState.showSnackbar("Račun za '$pub' uspešno poskeniran in shranjen!")
                }
            },
            onDismiss = { lokalForReceiptScan = null }
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LokalCard(
    lokal: Lokal,
    isVisited: Boolean,
    onCardClick: () -> Unit,
    onNavigate: () -> Unit,
    onLogVisit: () -> Unit,
    onScanReceipt: () -> Unit
) {
    val context = LocalContext.current

    // Categorize pub icon
    val icon: ImageVector = when {
        lokal.name.contains("kav|cafe|coffee", ignoreCase = true) -> Icons.Default.LocalCafe
        lokal.cuisine?.contains("burger|pizza|rest|food|sandwich", ignoreCase = true) == true -> Icons.Default.Restaurant
        else -> Icons.Default.SportsBar
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onCardClick),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // CARD HEADER (Icon + Name + Status Tag)
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Pub Icon avatar
                    Box(
                        modifier = Modifier
                            .size(42.dp)
                            .background(
                                color = MaterialTheme.colorScheme.primaryContainer,
                                shape = RoundedCornerShape(12.dp)
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = icon,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.size(24.dp)
                        )
                    }

                    Spacer(modifier = Modifier.width(12.dp))

                    Column {
                        Text(
                            text = lokal.name,
                            style = MaterialTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.5.sp
                            ),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Place,
                                contentDescription = null,
                                tint = DrajvRed,
                                modifier = Modifier.size(13.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            Text(
                                text = lokal.address,
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                ),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }

                if (isVisited) {
                    Box(
                        modifier = Modifier
                            .background(
                                color = DrajvGreen.copy(alpha = 0.15f),
                                shape = RoundedCornerShape(8.dp)
                            )
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = "Obiskano",
                            style = MaterialTheme.typography.labelSmall.copy(
                                color = DrajvGreen,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // CUISINE TAGS
            lokal.cuisine?.let { cuisine ->
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    cuisine.split(";").take(3).forEach { tag ->
                        Box(
                            modifier = Modifier
                                .background(
                                    color = MaterialTheme.colorScheme.surface,
                                    shape = RoundedCornerShape(6.dp)
                                )
                                .padding(horizontal = 8.dp, vertical = 3.dp)
                        ) {
                            Text(
                                text = tag.trim().replaceFirstChar { it.uppercase() },
                                style = MaterialTheme.typography.labelSmall.copy(
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.Medium
                                )
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            // DETAILS: OPENING HOURS & PHONE
            if (lokal.openingHours != null || lokal.phone != null) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    lokal.openingHours?.let { hours ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.AccessTime,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = hours,
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontSize = 12.sp
                                ),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    lokal.phone?.let { phone ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Phone,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = phone,
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontSize = 12.sp
                                )
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // ACTION BUTTONS ROW (Navigiraj, Zabeleži, Pokliči)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Primary Navigate Button
                Button(
                    onClick = onNavigate,
                    modifier = Modifier.weight(1.1f).height(40.dp),
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 0.dp),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary
                    )
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.DirectionsWalk,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Navigiraj",
                        maxLines = 1,
                        softWrap = false,
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp
                        )
                    )
                }

                // Log Visit Button
                OutlinedButton(
                    onClick = onLogVisit,
                    modifier = Modifier.weight(1.35f).height(40.dp),
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 0.dp),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.BookmarkAdded,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = if (isVisited) "Ponovni obisk" else "Označi",
                        maxLines = 1,
                        softWrap = false,
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 11.5.sp
                        )
                    )
                }

                // Phone quick button (if available)
                lokal.phone?.let { phone ->
                    IconButton(
                        onClick = {
                            val intent = Intent(Intent.ACTION_DIAL).apply {
                                data = Uri.parse("tel:$phone")
                            }
                            context.startActivity(intent)
                        },
                        modifier = Modifier
                            .size(40.dp)
                            .background(
                                color = MaterialTheme.colorScheme.surface,
                                shape = RoundedCornerShape(10.dp)
                            )
                    ) {
                        Icon(
                            imageVector = Icons.Default.Phone,
                            contentDescription = "Pokliči",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }

                // Scan receipt button
                IconButton(
                    onClick = onScanReceipt,
                    modifier = Modifier
                        .size(40.dp)
                        .background(
                            color = MaterialTheme.colorScheme.surface,
                            shape = RoundedCornerShape(10.dp)
                        )
                ) {
                    Icon(
                        imageVector = Icons.Default.QrCodeScanner,
                        contentDescription = "Skeniraj račun",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }
}

fun openInMaps(context: Context, lokal: Lokal) {
    val lat = lokal.lat
    val lon = lokal.lon
    val hasValidCoords = !(lat == 0.0 && lon == 0.0)

    val intent = if (hasValidCoords) {
        val uri = Uri.parse("google.navigation:q=$lat,$lon&mode=w")
        Intent(Intent.ACTION_VIEW, uri)
    } else {
        val qRaw = listOfNotNull(lokal.name, lokal.address).joinToString(", ")
        val q = URLEncoder.encode(qRaw, StandardCharsets.UTF_8.name())
        val uri = Uri.parse("geo:0,0?q=$q")
        Intent(Intent.ACTION_VIEW, uri)
    }

    // Trigger Lock Screen / Notification bar interactive session
    com.example.sankfinder.notifications.SankNotificationHelper.showOngoingPubSessionNotification(
        context,
        lokal.name,
        lokal.address
    )

    if (context !is Activity) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    try {
        if (intent.resolveActivity(context.packageManager) != null) {
            context.startActivity(intent)
        } else {
            val chooser = Intent.createChooser(intent, "Odpri v kartah")
            if (context !is Activity) {
                chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(chooser)
        }
    } catch (e: Exception) {
        println("Maps intent ni uspel: ${e.message}")
    }
}


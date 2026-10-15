package com.example.sankfinder.ui.pages

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LocalBar
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.example.compose.BeerGold
import com.example.compose.DrajvGreen
import com.example.compose.DrajvRed
import com.example.sankfinder.data.VisitHistory
import com.example.sankfinder.ui.components.AppTopBar
import com.example.sankfinder.ui.components.VisitDetailsDialog
import com.example.sankfinder.ui.navigation.BottomNavBar
import com.example.sankfinder.ui.navigation.Routes
import com.example.sankfinder.ui.viewmodels.VisitHistoryViewModel
import java.time.format.DateTimeFormatter

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.ReceiptLong
import com.example.sankfinder.ui.components.ReceiptScannerDialog
import com.example.sankfinder.ui.components.ReceiptViewDialog

@Composable
fun HistoryPage(navController: NavController) {
    val viewModel: VisitHistoryViewModel = viewModel()
    val history by viewModel.history.collectAsState()
    val context = LocalContext.current
    val formatter = DateTimeFormatter.ofPattern("dd. MM. yyyy 'ob' HH:mm")

    var showEditDialog by remember { mutableStateOf(false) }
    var selectedVisitIndex by remember { mutableIntStateOf(-1) }
    var selectedVisit by remember { mutableStateOf<VisitHistory?>(null) }
    var showReceiptScanner by remember { mutableStateOf(false) }
    var scannerTargetLokal by remember { mutableStateOf<com.example.sankfinder.data.Lokal?>(null) }
    var viewingReceiptVisit by remember { mutableStateOf<VisitHistory?>(null) }

    LaunchedEffect(Unit) {
        viewModel.loadFromStorage(context)
    }

    val totalVisits = history.size
    val totalDrinks = history.sumOf { it.drinks }
    val totalSpent = history.sumOf { it.amountSpent }

    Scaffold(
        topBar = {
            AppTopBar(
                title = "Zgodovina obiskov",
                currentRoute = Routes.HISTORY,
                onNavigationClick = { navController.popBackStack() }
            )
        },
        bottomBar = { BottomNavBar(navController = navController) }
    ) { padding ->
        if (history.isEmpty()) {
            // Friendly Empty State
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .background(MaterialTheme.colorScheme.primaryContainer, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.History,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.size(44.dp)
                    )
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text(
                    text = "Zgodovina je še prazna",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "Ko obiščete lokal ali kliknete 'Označi' pri poljubnem šanku, se bo vaša pot zabeležila tukaj. Lahko pa že takoj poskenirate račun!",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(24.dp))

                Button(
                    onClick = {
                        scannerTargetLokal = null
                        showReceiptScanner = true
                    },
                    modifier = Modifier.fillMaxWidth(0.85f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(imageVector = Icons.Default.QrCodeScanner, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Skeniraj račun (QR)")
                }

                Spacer(modifier = Modifier.height(10.dp))

                OutlinedButton(
                    onClick = { navController.navigate(Routes.MAIN) },
                    modifier = Modifier.fillMaxWidth(0.85f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(imageVector = Icons.Default.SportsBar, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Poišči šank v bližini")
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // RECEIPT SCANNER QUICK ACTION CARD
                item {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                scannerTargetLokal = null
                                showReceiptScanner = true
                            },
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                        ),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.45f))
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(46.dp)
                                    .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(12.dp)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = Icons.Default.QrCodeScanner,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onPrimary,
                                    modifier = Modifier.size(24.dp)
                                )
                            }

                            Spacer(modifier = Modifier.width(14.dp))

                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Skeniraj račun (QR koda / FURS)",
                                    style = MaterialTheme.typography.titleMedium.copy(
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 15.sp
                                    ),
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = "Samodejno preberi pijače in znesek ter osveži zgodovino",
                                    style = MaterialTheme.typography.bodySmall.copy(
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontSize = 12.sp
                                    )
                                )
                            }
                        }
                    }
                }

                // STATS SUMMARY CARD
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)
                        )
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                text = "Povzetek tvojih pohodov",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = MaterialTheme.colorScheme.onSurface
                            )

                            Spacer(modifier = Modifier.height(12.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                StatPill(
                                    title = "Obiskov",
                                    value = "$totalVisits",
                                    icon = Icons.Default.Place,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                StatPill(
                                    title = "Pijač",
                                    value = "$totalDrinks",
                                    icon = Icons.Default.SportsBar,
                                    color = BeerGold
                                )
                                StatPill(
                                    title = "Zapravljeno",
                                    value = "${String.format("%.1f", totalSpent)} €",
                                    icon = Icons.Default.Payments,
                                    color = DrajvGreen
                                )
                            }
                        }
                    }
                }

                // VISIT ITEMS
                itemsIndexed(history.reversed()) { index, visit ->
                    val actualIndex = history.lastIndex - index
                    val povprecje = if (visit.drinks > 0) String.format("%.2f", visit.amountSpent / visit.drinks) else "-"
                    val ocena = visit.rating?.let { String.format("%.1f", it) }

                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                        ),
                        elevation = CardDefaults.cardElevation(2.dp)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            // Pub Name & Date
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.Top
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = visit.lokal.name,
                                        style = MaterialTheme.typography.titleMedium.copy(
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 16.5.sp
                                        )
                                    )
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(
                                            imageVector = Icons.Default.Place,
                                            contentDescription = null,
                                            tint = DrajvRed,
                                            modifier = Modifier.size(13.dp)
                                        )
                                        Spacer(modifier = Modifier.width(3.dp))
                                        Text(
                                            text = visit.lokal.address,
                                            style = MaterialTheme.typography.bodySmall.copy(
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        )
                                    }
                                }

                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Default.AccessTime,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(12.dp)
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = visit.visitedAt.format(formatter),
                                        style = MaterialTheme.typography.labelSmall.copy(
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            fontSize = 11.sp
                                        )
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            // Badges Row (Drinks, Spent, Rating)
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                MetricBadge(
                                    label = "${visit.drinks} pijač",
                                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                                    textColor = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                                MetricBadge(
                                    label = "${String.format("%.2f", visit.amountSpent)} €",
                                    containerColor = DrajvGreen.copy(alpha = 0.15f),
                                    textColor = DrajvGreen
                                )
                                if (ocena != null) {
                                    MetricBadge(
                                        label = "Ocena: $ocena / 5",
                                        containerColor = BeerGold.copy(alpha = 0.18f),
                                        textColor = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }

                            if (visit.drinks > 0 && visit.amountSpent > 0.0) {
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = "Povprečje: $povprecje € / pijačo",
                                    style = MaterialTheme.typography.bodySmall.copy(
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontSize = 12.sp
                                    )
                                )
                            }

                            // User Note / Scanned Receipt Details
                            visit.note?.let { note ->
                                Spacer(modifier = Modifier.height(8.dp))
                                val isScannedReceipt = note.contains("Skenirano z računa") || note.contains("Prebrano z računa")
                                val isQrVerified = note.contains("[FURS QR]") || note.contains("FURS QR")
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .background(
                                            color = if (isScannedReceipt) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.25f)
                                                    else MaterialTheme.colorScheme.surface,
                                            shape = RoundedCornerShape(10.dp)
                                        )
                                        .padding(10.dp)
                                    ) {
                                        Column {
                                            if (isScannedReceipt) {
                                                Row(verticalAlignment = Alignment.CenterVertically) {
                                                    Icon(
                                                        imageVector = if (isQrVerified) Icons.Default.Receipt else Icons.Default.Receipt,
                                                        contentDescription = null,
                                                        tint = if (isQrVerified) DrajvGreen else MaterialTheme.colorScheme.primary,
                                                        modifier = Modifier.size(14.dp)
                                                    )
                                                    Spacer(modifier = Modifier.width(4.dp))
                                                    Text(
                                                        text = if (isQrVerified) "FURS QR verificiran račun" else "Prebrano z OCR (brez QR kode)",
                                                        style = MaterialTheme.typography.labelSmall.copy(
                                                            color = if (isQrVerified) DrajvGreen else MaterialTheme.colorScheme.primary,
                                                            fontWeight = FontWeight.Bold
                                                        )
                                                    )
                                                }
                                                Spacer(modifier = Modifier.height(4.dp))
                                            }
                                            val displayText = if (isScannedReceipt) {
                                                val colonIdx = note.indexOf(':')
                                                if (colonIdx != -1) note.substring(colonIdx + 1).trim() else note
                                            } else "\"$note\""

                                            Text(
                                                text = displayText,
                                                style = MaterialTheme.typography.bodySmall.copy(
                                                    fontStyle = if (isScannedReceipt) FontStyle.Normal else FontStyle.Italic,
                                                    color = MaterialTheme.colorScheme.onSurface,
                                                    fontSize = 12.sp
                                                )
                                            )
                                        }
                                    }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            val hasScannedReceipt = visit.note?.contains("računa") == true

                            // Action Buttons (Navigiraj, Račun (only if scanned), Uredi, Izbriši)
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                TextButton(
                                    onClick = { openInMaps(context, visit.lokal) }
                                ) {
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Filled.DirectionsWalk,
                                        contentDescription = null,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Navigiraj")
                                }

                                Row {
                                    if (hasScannedReceipt) {
                                        TextButton(onClick = {
                                            viewingReceiptVisit = visit
                                        }) {
                                            Icon(
                                                imageVector = Icons.Default.Receipt,
                                                contentDescription = null,
                                                modifier = Modifier.size(15.dp)
                                            )
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text("Račun")
                                        }
                                    }

                                    TextButton(onClick = {
                                        selectedVisitIndex = actualIndex
                                        selectedVisit = visit
                                        showEditDialog = true
                                    }) {
                                        Icon(
                                            imageVector = Icons.Default.Edit,
                                            contentDescription = null,
                                            modifier = Modifier.size(15.dp)
                                        )
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Uredi")
                                    }

                                    TextButton(
                                        onClick = { viewModel.removeVisit(context, actualIndex) },
                                        colors = ButtonDefaults.textButtonColors(contentColor = DrajvRed)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.DeleteOutline,
                                            contentDescription = null,
                                            modifier = Modifier.size(16.dp)
                                        )
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Izbriši")
                                    }
                                }
                            }
                        }
                    }
                }
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                }
            }
        }
    }

    if (viewingReceiptVisit != null) {
        ReceiptViewDialog(
            visit = viewingReceiptVisit!!,
            onDismiss = { viewingReceiptVisit = null }
        )
    }

    if (showReceiptScanner) {
        ReceiptScannerDialog(
            initialLokal = scannerTargetLokal,
            onReceiptScanned = { scannedVisit ->
                viewModel.addOrUpdateVisit(context, scannedVisit)
                showReceiptScanner = false
            },
            onDismiss = { showReceiptScanner = false }
        )
    }

    if (showEditDialog && selectedVisit != null) {
        VisitDetailsDialog(
            lokal = selectedVisit!!.lokal,
            initialVisit = selectedVisit,
            onConfirm = { updated ->
                viewModel.updateVisit(context, selectedVisitIndex, updated)
                showEditDialog = false
            },
            onDismiss = { showEditDialog = false }
        )
    }
}

@Composable
private fun StatPill(
    title: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(horizontal = 8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.ExtraBold,
                    color = MaterialTheme.colorScheme.onSurface
                )
            )
        }
        Text(
            text = title,
            style = MaterialTheme.typography.bodySmall.copy(
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 11.5.sp
            )
        )
    }
}

@Composable
private fun MetricBadge(
    label: String,
    containerColor: Color,
    textColor: Color
) {
    Box(
        modifier = Modifier
            .background(color = containerColor, shape = RoundedCornerShape(8.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall.copy(
                color = textColor,
                fontWeight = FontWeight.Bold
            )
        )
    }
}


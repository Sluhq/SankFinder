package com.example.sankfinder.ui.pages

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Fastfood
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.LocalTaxi
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.RotateRight
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.example.compose.BeerGold
import com.example.compose.DrajvGreen
import com.example.compose.DrajvRed
import com.example.sankfinder.data.Lokal
import com.example.sankfinder.ui.navigation.BottomNavBar
import com.example.sankfinder.ui.navigation.Routes
import com.example.sankfinder.ui.viewmodels.LokalViewModel
import com.example.sankfinder.ui.viewmodels.MapNavigationViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale
import kotlin.random.Random

@Composable
fun GamesPage(
    navController: NavController,
    lokalViewModel: LokalViewModel,
    mapNavViewModel: MapNavigationViewModel,
    squadViewModel: com.example.sankfinder.ui.viewmodels.SquadViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val lokali by lokalViewModel.lokali.collectAsState()
    val userLocation by mapNavViewModel.userLocation.collectAsState()

    // 1. RANDOM LOKAL STANJE
    var randomLokal by remember { mutableStateOf<Lokal?>(null) }
    var isRollingRandom by remember { mutableStateOf(false) }

    // 2. KDO PLAČA RUNDO STANJE (Kolo sreče)
    val friendsList = remember { mutableStateListOf("Ti", "Luka", "Maja", "Žiga") }
    var newFriendName by remember { mutableStateOf("") }
    var isSpinningWheel by remember { mutableStateOf(false) }
    var selectedPayer by remember { mutableStateOf<String?>(null) }
    var funPayerQuote by remember { mutableStateOf<String?>(null) }
    val wheelRotation = remember { Animatable(0f) }

    // 3. RAZDELI RAČUN STANJE
    var billSplitTab by remember { mutableIntStateOf(0) } // 0: Enakomerno, 1: Po osebah
    var totalAmountInput by remember { mutableStateOf("48.50") }
    var peopleCountInput by remember { mutableStateOf("4") }
    var selectedTipPercent by remember { mutableIntStateOf(0) }

    // 4. KONČAL SEM / TAKSI PREGOVORNI DIALOG Z NAKLJUČNIM ŠTEVILOM PREPRIČEVANJ (3 do 6)
    val allTaxiSteps = remember {
        listOf(
            TaxiConvinceStep(
                title = "Si res prepričan, da odnehaš?",
                message = "Noč v mestu je še mlada, pipe pa še točijo! Res greš že domov?",
                stayButton = "Imaš prav, še eno rundo!",
                leaveButton = "Res želim domov..."
            ),
            TaxiConvinceStep(
                title = "Čakaj malo... A res že zdaj?",
                message = "Tvoji prijatelji bodo rekli, da si copata! Šele pred kratkim smo začeli!",
                stayButton = "Bom še ostal!",
                leaveButton = "Vseeno klic taksija"
            ),
            TaxiConvinceStep(
                title = "Tvoja jetra pravijo: Zdrži!",
                message = "Zdrži vsaj še en deci cvička ali eno malo točeno pivo. Ne bodi takšen!",
                stayButton = "Ok, še eno pivo!",
                leaveButton = "Ne, res grem domov"
            ),
            TaxiConvinceStep(
                title = "Kaj pa Burek pavza?!",
                message = "Zlato pravilo šankanja: Brez vročega bureka se ne gre spat! Pojdi najprej na burek pavzo!",
                stayButton = "Grem na burek pavzo!",
                leaveButton = "Ne, taksi prosim"
            ),
            TaxiConvinceStep(
                title = "Legende nikoli ne obupajo!",
                message = "Ali je kdo kdaj postal legenda tako, da je šel spat pred polnočjo? Nikakor!",
                stayButton = "Ostajam do konca!",
                leaveButton = "Jaz nisem legenda, grem spat"
            ),
            TaxiConvinceStep(
                title = "Pivo brez tebe bo žalostno...",
                message = "Natakar ravno odpira nov sod, ti bi pa šel domov? Daj no, še en požirek!",
                stayButton = "Še en požirek!",
                leaveButton = "Ne, taksi zdaj"
            ),
            TaxiConvinceStep(
                title = "Kdo bo pa plačal zadnjo rundo?",
                message = "Ravno zdaj bi bila tvoja runda, pa že bežiš? Družba bo zamerila!",
                stayButton = "Častim še eno rundo!",
                leaveButton = "Jaz ne častim, domov grem"
            ),
            TaxiConvinceStep(
                title = "Zadnja priložnost za slavo!",
                message = "Če zdaj odnehaš, boš jutri cel dan poslušal opazke. Res pokličem taksi?",
                stayButton = "Nadaljuj s pohodom!",
                leaveButton = "Da, pokliči taksi zdaj!"
            )
        )
    }
    val activeTaxiSteps = remember { mutableStateListOf<TaxiConvinceStep>() }
    var taxiStepIndex by remember { mutableIntStateOf(0) }
    var isTaxiDialogOpen by remember { mutableStateOf(false) }
    var showFinalTaxiDialer by remember { mutableStateOf(false) }
    var showAllBurekSpots by remember { mutableStateOf(false) }
    var onlyOpenBurekSpots by remember { mutableStateOf(false) }

    Scaffold(
        bottomBar = { BottomNavBar(navController = navController) },
        containerColor = MaterialTheme.colorScheme.background
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            // HEADER
            item {
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Box(
                        modifier = Modifier
                            .size(46.dp)
                            .background(
                                brush = Brush.linearGradient(listOf(BeerGold, Color(0xFFD97706))),
                                shape = CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Build,
                            contentDescription = null,
                            tint = Color.Black,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "Šank Orodja",
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        Text(
                            text = "Kolo za rundo, burek rešitev, delitev računa in taksi",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // KARTICA 0: PIVSKA KLAPA (Live Chat & Radar prijateljev)
            item {
                val activeSquadRoom by squadViewModel.activeRoom.collectAsState()
                val squadMembers by squadViewModel.members.collectAsState()

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (activeSquadRoom != null) BeerGold.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    ),
                    border = if (activeSquadRoom != null) androidx.compose.foundation.BorderStroke(1.5.dp, BeerGold) else null,
                    elevation = CardDefaults.cardElevation(defaultElevation = 3.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Default.Groups,
                                    contentDescription = null,
                                    tint = BeerGold,
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Pivska Klapa (Chat & Radar)",
                                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                            if (activeSquadRoom != null) {
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = BeerGold
                                ) {
                                    Text(
                                        text = activeSquadRoom!!.code,
                                        color = Color.Black,
                                        fontWeight = FontWeight.ExtraBold,
                                        fontSize = 11.sp,
                                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp)
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = if (activeSquadRoom != null) {
                                "Povezan si v klapo '${activeSquadRoom!!.name}' z ${squadMembers.size} člani. Spremljaj njihove lokacije na mapi in klepetaj!"
                            } else {
                                "Ustvari klapo ali se pridruži s kodo, spremljaj prijatelje na zemljevidu v živo in beležite runde!"
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        Button(
                            onClick = { navController.navigate(Routes.SQUAD) },
                            modifier = Modifier.fillMaxWidth().height(44.dp),
                            shape = RoundedCornerShape(10.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = BeerGold)
                        ) {
                            Icon(
                                imageVector = if (activeSquadRoom != null) Icons.Default.Chat else Icons.Default.SportsBar,
                                contentDescription = null,
                                tint = Color.Black,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = if (activeSquadRoom != null) "Odpri Klapo & Klepet" else "Pridruži se ali ustvari klapo",
                                fontWeight = FontWeight.Bold,
                                color = Color.Black,
                                fontSize = 13.sp
                            )
                        }
                    }
                }
            }

            // KARTICA 1: NAKLJUČNI ŠANK (Pivska ruleta)
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 3.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Refresh, contentDescription = null, tint = BeerGold, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Pivska Ruleta (Naključni šank)",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Se ne morete odločiti, kam naprej? Naj usoda izbere naslednjo pivnico!",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        // Prikaz izbranega naključnega lokala
                        AnimatedVisibility(
                            visible = randomLokal != null,
                            enter = fadeIn(),
                            exit = fadeOut()
                        ) {
                            randomLokal?.let { lokal ->
                                SurfaceCard(
                                    modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            verticalAlignment = Alignment.Top
                                        ) {
                                            Column(modifier = Modifier.weight(1f)) {
                                                Text(
                                                    text = lokal.name,
                                                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                                                    color = MaterialTheme.colorScheme.primary
                                                )
                                                Text(
                                                    text = lokal.address,
                                                    style = MaterialTheme.typography.bodySmall,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                    maxLines = 1,
                                                    overflow = TextOverflow.Ellipsis
                                                )
                                            }
                                            Text(
                                                text = "Izbrano!",
                                                style = MaterialTheme.typography.labelSmall.copy(
                                                    color = BeerGold,
                                                    fontWeight = FontWeight.Bold
                                                )
                                            )
                                        }

                                        Spacer(modifier = Modifier.height(8.dp))
                                        Button(
                                            onClick = {
                                                mapNavViewModel.startNavigation(lokal)
                                                navController.navigate(Routes.MAIN)
                                            },
                                            modifier = Modifier.fillMaxWidth().height(38.dp),
                                            shape = RoundedCornerShape(10.dp),
                                            colors = ButtonDefaults.buttonColors(containerColor = BeerGold)
                                        ) {
                                            Icon(Icons.Default.Navigation, contentDescription = null, tint = Color.Black, modifier = Modifier.size(16.dp))
                                            Spacer(modifier = Modifier.width(6.dp))
                                            Text("Odpelji me tja!", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                        }
                                    }
                                }
                            }
                        }

                        Button(
                            onClick = {
                                val pool = if (lokali.isNotEmpty()) lokali else lokalViewModel.legendaryBurekSpots
                                if (pool.isNotEmpty()) {
                                    isRollingRandom = true
                                    coroutineScope.launch {
                                        // Kratka animacija mešanja
                                        repeat(6) {
                                            randomLokal = pool.random()
                                            delay(70)
                                        }
                                        isRollingRandom = false
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth().height(44.dp),
                            shape = RoundedCornerShape(12.dp),
                            enabled = !isRollingRandom,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primaryContainer,
                                contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        ) {
                            Icon(Icons.Default.Casino, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = if (isRollingRandom) "Vrtim ruleto..." else if (randomLokal == null) "Izžrebaj naključen šank" else "Izžrebaj drugega",
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }

            // KARTICA 2: BUREK PAVZA (Nočna lakota)
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 3.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Fastfood, contentDescription = null, tint = Color(0xFFFF9800), modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Burek Pavza (Nočna lakota)",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Ko po parih rundah zapaše vroč sirni ali mesni burek! Najdi najbližjo burekarno.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        // Filter za prikaz vseh ali samo trenutno odprtih pekarn
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = if (!onlyOpenBurekSpots) BeerGold.copy(alpha = 0.22f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                                modifier = Modifier.clickable { onlyOpenBurekSpots = false }
                            ) {
                                Text(
                                    text = "Vse točke (${lokalViewModel.legendaryBurekSpots.size})",
                                    fontSize = 11.5.sp,
                                    fontWeight = if (!onlyOpenBurekSpots) FontWeight.Bold else FontWeight.Medium,
                                    color = if (!onlyOpenBurekSpots) BeerGold else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                                )
                            }

                            val openSpotsCount = remember(lokalViewModel.legendaryBurekSpots) {
                                lokalViewModel.legendaryBurekSpots.count { getBakeryStatus(it.openingHours).first }
                            }

                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = if (onlyOpenBurekSpots) DrajvGreen.copy(alpha = 0.22f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                                modifier = Modifier.clickable { onlyOpenBurekSpots = true }
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(7.dp)
                                            .background(DrajvGreen, CircleShape)
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = "Odprto zdaj ($openSpotsCount)",
                                        fontSize = 11.5.sp,
                                        fontWeight = if (onlyOpenBurekSpots) FontWeight.Bold else FontWeight.Medium,
                                        color = if (onlyOpenBurekSpots) DrajvGreen else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        // Dinamično razvrščanje po razdalji in statusu odprtosti
                        val sortedBurekSpots = remember(userLocation, lokalViewModel.legendaryBurekSpots, onlyOpenBurekSpots) {
                            val loc = userLocation
                            val baseList = if (onlyOpenBurekSpots) {
                                lokalViewModel.legendaryBurekSpots.filter { getBakeryStatus(it.openingHours).first }
                            } else {
                                lokalViewModel.legendaryBurekSpots
                            }
                            if (loc != null) {
                                baseList.map { spot ->
                                    val results = FloatArray(1)
                                    android.location.Location.distanceBetween(loc.latitude, loc.longitude, spot.lat, spot.lon, results)
                                    spot to results[0]
                                }.sortedWith(
                                    compareBy(
                                        { if (onlyOpenBurekSpots) 0 else (!getBakeryStatus(it.first.openingHours).first) },
                                        { it.second }
                                    )
                                )
                            } else {
                                baseList.map { it to null }.sortedBy { !getBakeryStatus(it.first.openingHours).first }
                            }
                        }

                        val displayedBurekSpots = if (showAllBurekSpots) sortedBurekSpots else sortedBurekSpots.take(3)

                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            displayedBurekSpots.forEachIndexed { index, (spot, dist) ->
                                val (isOpen, statusText) = remember(spot) { getBakeryStatus(spot.openingHours) }

                                SurfaceCard(
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(
                                        modifier = Modifier.padding(12.dp).fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Text(
                                                    text = spot.name,
                                                    fontWeight = FontWeight.Bold,
                                                    fontSize = 14.sp,
                                                    color = MaterialTheme.colorScheme.onSurface
                                                )
                                                if (index == 0 && dist != null) {
                                                    Spacer(modifier = Modifier.width(6.dp))
                                                    Surface(
                                                        shape = RoundedCornerShape(4.dp),
                                                        color = BeerGold.copy(alpha = 0.2f)
                                                    ) {
                                                        Text(
                                                            text = "Najbližji",
                                                            fontSize = 9.5.sp,
                                                            fontWeight = FontWeight.Bold,
                                                            color = BeerGold,
                                                            modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                                                        )
                                                    }
                                                }
                                            }

                                            Spacer(modifier = Modifier.height(4.dp))

                                            // Status odprtosti in delovni čas
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Surface(
                                                    shape = RoundedCornerShape(4.dp),
                                                    color = if (isOpen) DrajvGreen.copy(alpha = 0.18f) else DrajvRed.copy(alpha = 0.18f)
                                                ) {
                                                    Text(
                                                        text = statusText,
                                                        fontSize = 10.5.sp,
                                                        fontWeight = FontWeight.Bold,
                                                        color = if (isOpen) DrajvGreen else DrajvRed,
                                                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                                                    )
                                                }
                                                if (spot.openingHours != null && !spot.openingHours.contains("24/7", ignoreCase = true)) {
                                                    Spacer(modifier = Modifier.width(6.dp))
                                                    Text(
                                                        text = spot.openingHours,
                                                        fontSize = 11.sp,
                                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                        maxLines = 1,
                                                        overflow = TextOverflow.Ellipsis
                                                    )
                                                }
                                            }

                                            Spacer(modifier = Modifier.height(3.dp))
                                            Text(
                                                text = spot.address,
                                                fontSize = 11.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f),
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis
                                            )

                                            if (dist != null) {
                                                val distMeters = dist.toInt()
                                                val distText = if (distMeters < 1000) "${distMeters} m" else String.format(Locale.US, "%.1f km", distMeters / 1000.0)
                                                val walkMin = (distMeters / 75).coerceAtLeast(1)
                                                Spacer(modifier = Modifier.height(3.dp))
                                                Text(
                                                    text = "$distText • ~$walkMin min hoje",
                                                    fontSize = 11.5.sp,
                                                    color = BeerGold,
                                                    fontWeight = FontWeight.SemiBold
                                                )
                                            }
                                        }

                                        Spacer(modifier = Modifier.width(8.dp))

                                        IconButton(
                                            onClick = {
                                                mapNavViewModel.startNavigation(spot)
                                                navController.navigate(Routes.MAIN)
                                            },
                                            modifier = Modifier
                                                .size(38.dp)
                                                .background(BeerGold.copy(alpha = 0.22f), CircleShape)
                                        ) {
                                            Icon(
                                                imageVector = Icons.AutoMirrored.Filled.DirectionsWalk,
                                                contentDescription = "Navigiraj na burek",
                                                tint = BeerGold,
                                                modifier = Modifier.size(20.dp)
                                            )
                                        }
                                    }
                                }
                            }

                            // Gumb za ogled vseh nočnih pekarn / burek točk
                            if (sortedBurekSpots.size > 3) {
                                TextButton(
                                    onClick = { showAllBurekSpots = !showAllBurekSpots },
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text(
                                        text = if (showAllBurekSpots) "Prikaži manj" else "Prikaži vse nočne točke (${sortedBurekSpots.size})",
                                        color = BeerGold,
                                        fontWeight = FontWeight.SemiBold,
                                        fontSize = 13.sp
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // KARTICA 3: KDO PLAČA RUNDO? (Kolo sreče)
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 3.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.SportsBar, contentDescription = null, tint = BeerGold, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Kolo Sreče: Kdo Plača Rundo?",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Vpišite družbo za mizo in zavrtite kolo. Poraženec odpre denarnico!",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        // Vnos novega prijatelja
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedTextField(
                                value = newFriendName,
                                onValueChange = { newFriendName = it },
                                placeholder = { Text("Ime prijatelja...", fontSize = 12.5.sp) },
                                singleLine = true,
                                modifier = Modifier.weight(1f).height(50.dp),
                                shape = RoundedCornerShape(10.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Button(
                                onClick = {
                                    val trimmed = newFriendName.trim()
                                    if (trimmed.isNotBlank() && !friendsList.contains(trimmed)) {
                                        friendsList.add(trimmed)
                                        newFriendName = ""
                                    }
                                },
                                modifier = Modifier.height(50.dp),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Icon(Icons.Default.Add, contentDescription = "Dodaj")
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        // Seznam prijateljev v obliki značk
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            friendsList.forEach { friend ->
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = MaterialTheme.colorScheme.surface,
                                    border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                    ) {
                                        Text(friend, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                                        if (friendsList.size > 2) {
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Icon(
                                                imageVector = Icons.Default.Close,
                                                contentDescription = "Odstrani",
                                                modifier = Modifier.size(14.dp).clickable { friendsList.remove(friend) },
                                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Prikaz pivskega kolesa s kazalcem
                        Box(
                            modifier = Modifier.fillMaxWidth().height(160.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            // Kolo
                            WheelOfBeerCanvas(
                                names = friendsList,
                                rotation = wheelRotation.value,
                                modifier = Modifier.size(150.dp)
                            )

                            // Sredinska pivska pika
                            Box(
                                modifier = Modifier
                                    .size(34.dp)
                                    .background(Color(0xFF1E293B), CircleShape)
                                    .border(2.dp, BeerGold, CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.SportsBar, contentDescription = null, tint = BeerGold, modifier = Modifier.size(18.dp))
                            }

                            // Rdeči kazalec na vrhu
                            Box(
                                modifier = Modifier
                                    .size(14.dp)
                                    .align(Alignment.TopCenter)
                                    .background(DrajvRed, CircleShape)
                                    .border(1.5.dp, Color.White, CircleShape)
                            )
                        }

                        // Rezultat žrebanja
                        AnimatedVisibility(visible = selectedPayer != null) {
                            selectedPayer?.let { payer ->
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(top = 10.dp)
                                        .background(BeerGold.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                                        .border(1.dp, BeerGold, RoundedCornerShape(12.dp))
                                        .padding(12.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Text(
                                        text = "Rundo časti: $payer!",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 17.sp,
                                        color = BeerGold
                                    )
                                    funPayerQuote?.let { quote ->
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = "\"$quote\"",
                                            fontSize = 12.sp,
                                            textAlign = TextAlign.Center,
                                            fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Gumb Zavrti kolo
                        Button(
                            onClick = {
                                if (friendsList.isNotEmpty() && !isSpinningWheel) {
                                    isSpinningWheel = true
                                    selectedPayer = null
                                    coroutineScope.launch {
                                        val randomSpins = Random.nextInt(4, 8) * 360f
                                        val randomExtra = Random.nextFloat() * 360f
                                        val targetRotation = wheelRotation.value + randomSpins + randomExtra

                                        wheelRotation.animateTo(
                                            targetValue = targetRotation,
                                            animationSpec = tween(durationMillis = 2800, easing = LinearOutSlowInEasing)
                                        )

                                        // Izračunaj zmagovalca glede na končni kot
                                        val normalizedAngle = (360f - (wheelRotation.value % 360f)) % 360f
                                        val sliceAngle = 360f / friendsList.size
                                        val winnerIndex = (normalizedAngle / sliceAngle).toInt().coerceIn(0, friendsList.lastIndex)
                                        val winner = friendsList[winnerIndex]

                                        val quotes = listOf(
                                            "Pivski bogovi so odločili: $winner, odpri tošl!",
                                            "$winner plača, ker se že pol ure dela, da išče denarnico!",
                                            "Danes je tvoj srečni dan, $winner! Runda je tvoja čast!",
                                            "$winner plača za celo mizo, naslednjič pa pije samo vodo!",
                                            "Kelner, račun nesi $winner-ju! Vsi na njegovo zdravje!"
                                        )

                                        selectedPayer = winner
                                        funPayerQuote = quotes.random()
                                        isSpinningWheel = false
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth().height(44.dp),
                            shape = RoundedCornerShape(12.dp),
                            enabled = !isSpinningWheel,
                            colors = ButtonDefaults.buttonColors(containerColor = BeerGold)
                        ) {
                            Icon(Icons.Default.RotateRight, contentDescription = null, tint = Color.Black, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = if (isSpinningWheel) "Kolo se vrti..." else "Zavrti kolo za rundo!",
                                fontWeight = FontWeight.Bold,
                                color = Color.Black
                            )
                        }
                    }
                }
            }

            // KARTICA 4: RAZDELI RAČUN (Kdo je koliko dolžen?)
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 3.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Payments, contentDescription = null, tint = DrajvGreen, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Kalkulator Runde (Razdeli račun)",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Hitro in pošteno razdelite stroške runde brez prepirov.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(14.dp))

                        // Vnos skupnega zneska in števila oseb
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            OutlinedTextField(
                                value = totalAmountInput,
                                onValueChange = { totalAmountInput = it },
                                label = { Text("Znesek (€)", fontSize = 12.sp) },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                                singleLine = true,
                                modifier = Modifier.weight(1f),
                                shape = RoundedCornerShape(10.dp)
                            )

                            OutlinedTextField(
                                value = peopleCountInput,
                                onValueChange = { peopleCountInput = it.filter { c -> c.isDigit() } },
                                label = { Text("Št. oseb", fontSize = 12.sp) },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                singleLine = true,
                                modifier = Modifier.weight(1f),
                                shape = RoundedCornerShape(10.dp)
                            )
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        // Napitnina čipi (0%, 5%, 10%)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Napitnina:", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            listOf(0, 5, 10).forEach { pct ->
                                FilterChip(
                                    selected = selectedTipPercent == pct,
                                    onClick = { selectedTipPercent = pct },
                                    label = { Text("$pct%", fontSize = 11.5.sp) },
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = DrajvGreen.copy(alpha = 0.2f),
                                        selectedLabelColor = DrajvGreen
                                    )
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Izračun
                        val total = totalAmountInput.replace(',', '.').toDoubleOrNull() ?: 0.0
                        val count = peopleCountInput.toIntOrNull()?.coerceAtLeast(1) ?: 1
                        val totalWithTip = total * (1.0 + selectedTipPercent / 100.0)
                        val perPerson = totalWithTip / count

                        SurfaceCard(
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(
                                modifier = Modifier.padding(14.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = "Vsak plača:",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    text = String.format(Locale.US, "%.2f €", perPerson),
                                    fontSize = 24.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = DrajvGreen
                                )
                                if (selectedTipPercent > 0) {
                                    Text(
                                        text = "Skupaj z napitnino: ${String.format(Locale.US, "%.2f", totalWithTip)} €",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // KARTICA 5: GUMB "KONČAL SEM / POKLIČI TAKSI" S 5-STOPANJSKIM PREGOVARJANJEM
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.5.dp, DrajvRed.copy(alpha = 0.5f), RoundedCornerShape(18.dp)),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = DrajvRed.copy(alpha = 0.08f)
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.LocalTaxi, contentDescription = null, tint = DrajvRed, modifier = Modifier.size(22.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Končal sem za danes / Pokliči Taksi",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Preveč rund? Pritisnite za taksi... ampak opozorilo: aplikacija te bo poskusila prepričati v še eno!",
                            style = MaterialTheme.typography.bodySmall,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(14.dp))

                        Button(
                            onClick = {
                                val randomCount = Random.nextInt(3, 7) // Naključno 3, 4, 5 ali 6 prepričevanj!
                                activeTaxiSteps.clear()
                                activeTaxiSteps.addAll(allTaxiSteps.shuffled().take(randomCount))
                                taxiStepIndex = 0
                                isTaxiDialogOpen = true
                                showFinalTaxiDialer = false
                            },
                            modifier = Modifier.fillMaxWidth().height(48.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = DrajvRed)
                        ) {
                            Icon(Icons.Default.LocalTaxi, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Naj ti bo, zaključil si z danes!", fontWeight = FontWeight.Bold, color = Color.White)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }

    // NAKLJUČNI DIALOGI ZA PREGOVARJANJE PRED KLICEM TAKSIJA (Brez številk in z naključnim trajanjem)
    if (isTaxiDialogOpen && taxiStepIndex in activeTaxiSteps.indices) {
        val stepData = activeTaxiSteps[taxiStepIndex]

        AlertDialog(
            onDismissRequest = {
                isTaxiDialogOpen = false
                taxiStepIndex = 0
            },
            icon = {
                Icon(Icons.Default.SportsBar, contentDescription = null, tint = BeerGold, modifier = Modifier.size(34.dp))
            },
            title = {
                Text(stepData.title, fontWeight = FontWeight.Bold, fontSize = 17.sp, textAlign = TextAlign.Center)
            },
            text = {
                Text(stepData.message, fontSize = 14.sp, textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurface)
            },
            confirmButton = {
                Button(
                    onClick = {
                        // "Imaš prav, ostanem!" -> Zapri in ostani
                        isTaxiDialogOpen = false
                        taxiStepIndex = 0
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = BeerGold)
                ) {
                    Text(stepData.stayButton, color = Color.Black, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        // Gre naprej na naslednje naključno prepričevanje ali na končni klic taksija
                        if (taxiStepIndex + 1 < activeTaxiSteps.size) {
                            taxiStepIndex += 1
                        } else {
                            isTaxiDialogOpen = false
                            showFinalTaxiDialer = true
                        }
                    }
                ) {
                    Text(stepData.leaveButton, color = DrajvRed)
                }
            }
        )
    }

    // KONČNI DIALOG ZA KLIC TAKSIJA (po uspešno prestanih vseh prepričevanjih)
    if (showFinalTaxiDialer) {
        AlertDialog(
            onDismissRequest = { showFinalTaxiDialer = false },
            icon = {
                Icon(Icons.Default.LocalTaxi, contentDescription = null, tint = DrajvRed, modifier = Modifier.size(36.dp))
            },
            title = {
                Text("Čas je za domov...", fontWeight = FontWeight.Bold, fontSize = 18.sp, textAlign = TextAlign.Center)
            },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        "Večer se počasi zaključuje in šanki zapirajo vrata. Poskrbi za varno pot v toplo posteljo:",
                        fontSize = 13.5.sp,
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            },
            confirmButton = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Button(
                        onClick = {
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:0801190"))
                            context.startActivity(intent)
                            showFinalTaxiDialer = false
                        },
                        modifier = Modifier.fillMaxWidth().height(46.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = DrajvRed)
                    ) {
                        Text("Pokliči Taxi Metro (080 11 90)", color = Color.White, fontWeight = FontWeight.Bold)
                    }

                    Button(
                        onClick = {
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:0801233"))
                            context.startActivity(intent)
                            showFinalTaxiDialer = false
                        },
                        modifier = Modifier.fillMaxWidth().height(46.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                    ) {
                        Text("Pokliči Taxi Laguna (080 12 33)", color = MaterialTheme.colorScheme.onSurface, fontWeight = FontWeight.Bold)
                    }

                    Spacer(modifier = Modifier.height(2.dp))

                    TextButton(
                        onClick = { showFinalTaxiDialer = false },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Prekliči, še malo ostanem...", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            },
            dismissButton = null
        )
    }
}

private data class TaxiConvinceStep(
    val title: String,
    val message: String,
    val stayButton: String,
    val leaveButton: String
)

@Composable
private fun SurfaceCard(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
    ) {
        content()
    }
}

/**
 * Preprosto, lepo pivsko kolo z izseki za vsakega prijatelja.
 */
@Composable
private fun WheelOfBeerCanvas(
    names: List<String>,
    rotation: Float,
    modifier: Modifier = Modifier
) {
    val colors = listOf(
        Color(0xFFFFB703),
        Color(0xFFFB8500),
        Color(0xFF023047),
        Color(0xFF219EBC),
        Color(0xFF8ECAE6),
        Color(0xFF9C27B0)
    )

    Canvas(modifier = modifier.rotate(rotation)) {
        val count = names.size.coerceAtLeast(1)
        val sliceAngle = 360f / count

        for (i in 0 until count) {
            val color = colors[i % colors.size]
            drawArc(
                color = color,
                startAngle = i * sliceAngle,
                sweepAngle = sliceAngle,
                useCenter = true
            )
        }

        // Beli zunanji rob
        drawCircle(
            color = Color.White,
            radius = size.width / 2f,
            style = Stroke(width = 3.dp.toPx())
        )
    }
}

/**
 * Preveri ali je pekarna/burekarna trenutno odprta glede na uro in dan v tednu.
 */
private fun getBakeryStatus(openingHours: String?): Pair<Boolean, String> {
    if (openingHours == null) return Pair(true, "Odprto")
    if (openingHours.contains("24/7", ignoreCase = true) || openingHours.contains("Non-stop", ignoreCase = true)) {
        return Pair(true, "24/7 Odprto")
    }

    val cal = java.util.Calendar.getInstance()
    val hour = cal.get(java.util.Calendar.HOUR_OF_DAY)
    val dayOfWeek = cal.get(java.util.Calendar.DAY_OF_WEEK) // 1=Nedelja, 7=Sobota

    if (openingHours.contains("06:00 - 03:00") || openingHours.contains("06:00-03:00")) {
        val isOpen = hour < 3 || hour >= 6
        return Pair(isOpen, if (isOpen) "Odprto zdaj (do 03:00)" else "Zaprto (odpre ob 06:00)")
    }
    if (openingHours.contains("06:00 - 04:00") || openingHours.contains("06:00-04:00")) {
        val isOpen = hour < 4 || hour >= 6
        return Pair(isOpen, if (isOpen) "Odprto zdaj (do 04:00)" else "Zaprto (odpre ob 06:00)")
    }
    if (openingHours.contains("09:00 - 03:00")) {
        val isOpen = hour < 3 || hour >= 9
        return Pair(isOpen, if (isOpen) "Odprto zdaj (do 03:00)" else "Zaprto (odpre ob 09:00)")
    }
    if (openingHours.contains("06:00 - 22:00") || openingHours.contains("06.00–22.00")) {
        val isOpen = hour in 6..21
        return Pair(isOpen, if (isOpen) "Odprto zdaj (do 22:00)" else "Zaprto (odpre ob 06:00)")
    }
    if (openingHours.contains("06:00 - 19:00") || openingHours.contains("05:30 - 19:00")) {
        if (dayOfWeek == java.util.Calendar.SUNDAY) {
            return Pair(false, "Zaprto ob nedeljah")
        }
        if (dayOfWeek == java.util.Calendar.SATURDAY) {
            val isOpen = hour in 7..12
            return Pair(isOpen, if (isOpen) "Odprto zdaj (do 13:00)" else "Zaprto čez vikend")
        }
        val isOpen = hour in 6..18
        return Pair(isOpen, if (isOpen) "Odprto zdaj (do 19:00)" else "Zaprto (odpre ob 06:00)")
    }
    if (openingHours.contains("07:00 - 19:00")) {
        if (dayOfWeek == java.util.Calendar.SATURDAY) {
            return Pair(false, "Zaprto ob sobotah")
        }
        val maxHour = if (dayOfWeek == java.util.Calendar.SUNDAY) 16 else 18
        val isOpen = hour in 7..maxHour
        return Pair(isOpen, if (isOpen) "Odprto" else "Zaprto")
    }

    return Pair(true, "Preveri urnik")
}

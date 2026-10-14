package com.example.sankfinder.ui.pages

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.Fastfood
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.LocalDrink
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.example.compose.BeerGold
import com.example.compose.DrajvGreen
import com.example.compose.DrajvRed
import com.example.sankfinder.data.SquadMessage
import com.example.sankfinder.ui.navigation.Routes
import com.example.sankfinder.ui.viewmodels.SquadViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SquadPage(
    navController: NavController,
    squadViewModel: SquadViewModel
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    val activeRoom by squadViewModel.activeRoom.collectAsState()
    val members by squadViewModel.members.collectAsState()
    val messages by squadViewModel.messages.collectAsState()
    val isConnected by squadViewModel.isConnected.collectAsState()
    val isLoading by squadViewModel.isLoading.collectAsState()
    val errorMessage by squadViewModel.errorMessage.collectAsState()
    val bannerAlert by squadViewModel.bannerAlert.collectAsState()
    val myUserName by squadViewModel.myUserName.collectAsState()

    var joinTab by remember { mutableIntStateOf(0) } // 0: Pridruži se, 1: Ustvari novo
    var inputCode by remember { mutableStateOf("") }
    var inputRoomName by remember { mutableStateOf("") }
    var inputUserName by remember { mutableStateOf(myUserName) }
    var chatInput by remember { mutableStateOf("") }
    var showLeaveDialog by remember { mutableStateOf(false) }
    var showTrackerSheet by remember { mutableStateOf(false) }

    val listState = rememberLazyListState()

    // Avtomatski premik na zadnje sporočilo
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    // Prikaz napak kot toast
    LaunchedEffect(errorMessage) {
        errorMessage?.let {
            Toast.makeText(context, it, Toast.LENGTH_LONG).show()
            squadViewModel.clearError()
        }
    }

    if (showLeaveDialog) {
        AlertDialog(
            onDismissRequest = { showLeaveDialog = false },
            title = { Text("Zapusti klapo?", fontWeight = FontWeight.Bold) },
            text = {
                Text("Ali si prepričan, da želiš zapustiti to Pivsko Klapo? S tem boš prekinil klepet v živo in deljenje lokacije.")
            },
            confirmButton = {
                Button(
                    onClick = {
                        showLeaveDialog = false
                        squadViewModel.leaveSquad()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = DrajvRed)
                ) {
                    Text("Zapusti", color = Color.White, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showLeaveDialog = false }) {
                    Text("Prekliči")
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = if (activeRoom != null) activeRoom!!.name else "Pivska Klapa",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (activeRoom != null) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(7.dp)
                                        .background(if (isConnected) DrajvGreen else DrajvRed, CircleShape)
                                )
                                Spacer(modifier = Modifier.width(5.dp))
                                Text(
                                    text = if (isConnected) "Povezano v živo (${members.size} članov)" else "Povezovanje...",
                                    fontSize = 11.sp,
                                    color = if (isConnected) DrajvGreen else DrajvRed
                                )
                            }
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Nazaj")
                    }
                },
                actions = {
                    if (activeRoom != null) {
                        // Koda sobe s klikom za kopiranje
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = BeerGold.copy(alpha = 0.2f),
                            modifier = Modifier
                                .clickable {
                                    clipboardManager.setText(AnnotatedString(activeRoom!!.code))
                                    Toast.makeText(context, "Koda ${activeRoom!!.code} kopirana!", Toast.LENGTH_SHORT).show()
                                }
                                .padding(end = 4.dp)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp)
                            ) {
                                Text(
                                    text = activeRoom!!.code,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = BeerGold,
                                    fontSize = 13.sp,
                                    letterSpacing = 1.sp
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Icon(
                                    Icons.Default.ContentCopy,
                                    contentDescription = "Kopiraj",
                                    tint = BeerGold,
                                    modifier = Modifier.size(14.dp)
                                )
                            }
                        }

                        // Gumb za izvoz / shranjevanje klepeta
                        IconButton(onClick = {
                            val chatExport = buildString {
                                appendLine("ŠankFinder - Pivska Klapa: ${activeRoom?.name} (${activeRoom?.code})")
                                appendLine("Izvoz klepeta: ${java.text.SimpleDateFormat("dd.MM.yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date())}")
                                appendLine("--- Sporočila ---")
                                messages.forEach { msg ->
                                    if (msg.msgType == "system") {
                                        appendLine("[Sistem] ${msg.content}")
                                    } else {
                                        appendLine("${msg.senderName}: ${msg.content}")
                                    }
                                }
                                appendLine("--- Osebni števec pijač ---")
                                val myDrinkCount = members.find { it.id == squadViewModel.myUserId }?.drinksCount ?: 0
                                appendLine("- Tvoje zabeležene pijače: $myDrinkCount")
                            }
                            val sendIntent = android.content.Intent().apply {
                                action = android.content.Intent.ACTION_SEND
                                putExtra(android.content.Intent.EXTRA_TEXT, chatExport)
                                putExtra(android.content.Intent.EXTRA_TITLE, "Klepet - ${activeRoom?.name}")
                                type = "text/plain"
                            }
                            val chooser = android.content.Intent.createChooser(sendIntent, "Shrani ali deli klepet")
                            context.startActivity(chooser)
                        }) {
                            Icon(Icons.Default.Share, contentDescription = "Shrani ali deli klepet", tint = BeerGold)
                        }

                        // Gumb za zemljevid z radarjem
                        IconButton(onClick = { navController.navigate(Routes.MAIN) }) {
                            Icon(Icons.Default.Map, contentDescription = "Radar na zemljevidu", tint = BeerGold)
                        }

                        // Zapusti klapo (z opozorilom)
                        IconButton(onClick = { showLeaveDialog = true }) {
                            Icon(Icons.Default.ExitToApp, contentDescription = "Zapusti", tint = DrajvRed)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            if (activeRoom == null) {
                // ==========================================
                // 1. ZASLON ZA VSTOP / USTVARJANJE SOBE
                // ==========================================
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    item {
                        Spacer(modifier = Modifier.height(10.dp))
                        Box(
                            modifier = Modifier
                                .size(74.dp)
                                .background(
                                    brush = Brush.linearGradient(listOf(BeerGold, Color(0xFFD97706))),
                                    shape = CircleShape
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Groups,
                                contentDescription = null,
                                tint = Color.Black,
                                modifier = Modifier.size(40.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = "Pivska Klapa",
                            style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.ExtraBold),
                            color = BeerGold
                        )
                        Text(
                            text = "Skupinsko šankanje, vodenje po mestu, runda števec in live radar prijateljev na zemljevidu!",
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 16.dp)
                        )
                    }

                    item {
                        // Preklopnik zavihkov
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(modifier = Modifier.padding(4.dp)) {
                                Button(
                                    onClick = { joinTab = 0 },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(10.dp),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = if (joinTab == 0) BeerGold else Color.Transparent,
                                        contentColor = if (joinTab == 0) Color.Black else MaterialTheme.colorScheme.onSurface
                                    ),
                                    elevation = null
                                ) {
                                    Text("Pridruži se klapi", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                }
                                Button(
                                    onClick = { joinTab = 1 },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(10.dp),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = if (joinTab == 1) BeerGold else Color.Transparent,
                                        contentColor = if (joinTab == 1) Color.Black else MaterialTheme.colorScheme.onSurface
                                    ),
                                    elevation = null
                                ) {
                                    Text("Ustvari novo", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                }
                            }
                        }
                    }

                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                            )
                        ) {
                            Column(
                                modifier = Modifier.padding(18.dp),
                                verticalArrangement = Arrangement.spacedBy(14.dp)
                            ) {
                                // Vzdevek
                                OutlinedTextField(
                                    value = inputUserName,
                                    onValueChange = { inputUserName = it },
                                    label = { Text("Tvoje ime ali vzdevek") },
                                    placeholder = { Text("npr. Anže") },
                                    singleLine = true,
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = BeerGold,
                                        focusedLabelColor = BeerGold
                                    )
                                )

                                if (joinTab == 0) {
                                    // Vnos 4-mestne kode
                                    OutlinedTextField(
                                        value = inputCode,
                                        onValueChange = { if (it.length <= 4) inputCode = it.uppercase() },
                                        label = { Text("4-mestna koda klape") },
                                        placeholder = { Text("npr. RK9V") },
                                        singleLine = true,
                                        modifier = Modifier.fillMaxWidth(),
                                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                                        colors = OutlinedTextFieldDefaults.colors(
                                            focusedBorderColor = BeerGold,
                                            focusedLabelColor = BeerGold
                                        )
                                    )

                                    Button(
                                        onClick = {
                                            if (inputUserName.isNotBlank() && inputCode.isNotBlank()) {
                                                squadViewModel.joinSquad(inputCode, inputUserName)
                                            } else {
                                                Toast.makeText(context, "Vpiši svoje ime in kodo sobe!", Toast.LENGTH_SHORT).show()
                                            }
                                        },
                                        enabled = !isLoading,
                                        modifier = Modifier.fillMaxWidth().height(48.dp),
                                        shape = RoundedCornerShape(12.dp),
                                        colors = ButtonDefaults.buttonColors(containerColor = BeerGold)
                                    ) {
                                        if (isLoading) {
                                            CircularProgressIndicator(color = Color.Black, modifier = Modifier.size(20.dp))
                                        } else {
                                            Icon(Icons.Default.SportsBar, contentDescription = null, tint = Color.Black)
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text("Vstopi v klapo", fontWeight = FontWeight.Bold, color = Color.Black)
                                        }
                                    }
                                } else {
                                    // Ustvari novo sobo
                                    OutlinedTextField(
                                        value = inputRoomName,
                                        onValueChange = { inputRoomName = it },
                                        label = { Text("Ime skupine / večera") },
                                        placeholder = { Text("npr. Ljubljana Žur") },
                                        singleLine = true,
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = OutlinedTextFieldDefaults.colors(
                                            focusedBorderColor = BeerGold,
                                            focusedLabelColor = BeerGold
                                        )
                                    )

                                    Button(
                                        onClick = {
                                            if (inputUserName.isNotBlank()) {
                                                squadViewModel.createSquad(inputRoomName, inputUserName)
                                            } else {
                                                Toast.makeText(context, "Vpiši svoje ime!", Toast.LENGTH_SHORT).show()
                                            }
                                        },
                                        enabled = !isLoading,
                                        modifier = Modifier.fillMaxWidth().height(48.dp),
                                        shape = RoundedCornerShape(12.dp),
                                        colors = ButtonDefaults.buttonColors(containerColor = BeerGold)
                                    ) {
                                        if (isLoading) {
                                            CircularProgressIndicator(color = Color.Black, modifier = Modifier.size(20.dp))
                                        } else {
                                            Icon(Icons.Default.Groups, contentDescription = null, tint = Color.Black)
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text("Ustvari novo klapo", fontWeight = FontWeight.Bold, color = Color.Black)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    item {
                        // Navodila
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.25f),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(
                                    text = "Kako deluje Pivska Klapa?",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp,
                                    color = BeerGold
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "• Ko se pridružite, se na zemljevidu izrišejo ikonice prijateljev v živo.\n" +
                                            "• Vsak lahko beleži svoje pijače, da se točno ve, kdo je na vrsti za rundo.\n" +
                                            "• Hitri gumbi omogočajo takojšnje sporočanje lokacije in časa prihoda.",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    lineHeight = 18.sp
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(24.dp))
                    }
                }
            } else {
                // ==========================================
                // 2. AKTIVNA KLAPA: CHAT & RUNDA TRACKER
                // ==========================================
                Column(modifier = Modifier.fillMaxSize()) {

                    // ENOTNA PREČIŠČENA STATUSNA VRSTICA (TRACKER SUBMENI + HITRI ŠTEVEC)
                    val totalSquadDrinks = members.sumOf { it.drinksCount }
                    val myDrinkCount = members.find { it.id == squadViewModel.myUserId }?.drinksCount ?: 0

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 14.dp, vertical = 6.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Gumb za odpiranje podmenija trackerja pijač
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f),
                            modifier = Modifier.clickable { showTrackerSheet = true }
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp)
                            ) {
                                Icon(
                                    Icons.Default.SportsBar,
                                    contentDescription = null,
                                    tint = BeerGold,
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "Tracker ($totalSquadDrinks piv • ${members.size} oseb)",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.5.sp,
                                    color = Color.White
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Icon(
                                    Icons.Default.ArrowDropDown,
                                    contentDescription = "Odpri meni",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }

                        // Simetričen osebni števec [-] [count] [+]
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(3.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(28.dp)
                                        .clip(RoundedCornerShape(6.dp))
                                        .background(MaterialTheme.colorScheme.surfaceVariant)
                                        .clickable { squadViewModel.decrementDrinks() },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("-", fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface)
                                }

                                Text(
                                    text = "$myDrinkCount",
                                    fontWeight = FontWeight.ExtraBold,
                                    color = BeerGold,
                                    fontSize = 14.sp,
                                    textAlign = TextAlign.Center,
                                    modifier = Modifier.width(28.dp)
                                )

                                Box(
                                    modifier = Modifier
                                        .size(28.dp)
                                        .clip(RoundedCornerShape(6.dp))
                                        .background(BeerGold)
                                        .clickable { squadViewModel.incrementDrinks() },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(Icons.Default.Add, contentDescription = "+1", tint = Color.Black, modifier = Modifier.size(14.dp))
                                }
                            }
                        }
                    }

                    // SPOROČILA V ŽIVO (SEZNAM)
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .padding(horizontal = 14.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        contentPadding = PaddingValues(vertical = 10.dp)
                    ) {
                        items(messages) { msg ->
                            ChatMessageItem(
                                message = msg,
                                isMe = msg.senderId == squadViewModel.myUserId
                            )
                        }
                    }

                    // HITRE AKCIJE (HORIZONTALNI TRAK)
                    LazyRow(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        item {
                            QuickActionChip(text = "Naročil sem rundo!") {
                                squadViewModel.sendQuickAction("Naročil sem novo rundo za mizo! Na zdravje!", "round_call")
                            }
                        }
                        item {
                            QuickActionChip(text = "Kdo gre na hrano?") {
                                squadViewModel.sendQuickAction("Kdo gre na malico? Jaz sem lačen!", "quick")
                            }
                        }
                        item {
                            QuickActionChip(text = "Pridem čez 5 min") {
                                squadViewModel.sendQuickAction("Sem že na poti, pridem čez ~5 min!", "eta")
                            }
                        }
                        item {
                            QuickActionChip(text = "Kje točno sedite?") {
                                squadViewModel.sendQuickAction("Kje točno sedite? Sem pri vhodu!", "quick")
                            }
                        }
                    }

                    // VNOSNO POLJE ZA BESEDILO
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                        shadowElevation = 6.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedTextField(
                                value = chatInput,
                                onValueChange = { chatInput = it },
                                placeholder = { Text("Napiši sporočilo...", fontSize = 13.sp) },
                                modifier = Modifier.weight(1f),
                                maxLines = 3,
                                shape = RoundedCornerShape(20.dp),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = BeerGold,
                                    unfocusedBorderColor = Color.Transparent
                                ),
                                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                                keyboardActions = KeyboardActions(
                                    onSend = {
                                        if (chatInput.isNotBlank()) {
                                            squadViewModel.sendMessage(chatInput)
                                            chatInput = ""
                                        }
                                    }
                                )
                            )

                            Spacer(modifier = Modifier.width(8.dp))

                            IconButton(
                                onClick = {
                                    if (chatInput.isNotBlank()) {
                                        squadViewModel.sendMessage(chatInput)
                                        chatInput = ""
                                    }
                                },
                                modifier = Modifier
                                    .size(44.dp)
                                    .background(BeerGold, CircleShape)
                            ) {
                                Icon(Icons.AutoMirrored.Filled.Send, contentDescription = "Pošlji", tint = Color.Black)
                            }
                        }
                    }
                }
            }

            // OPOZORILNA PLAVAJOČA ZNAČKA (BANNER ALERT)
            AnimatedVisibility(
                visible = bannerAlert != null,
                enter = fadeIn(),
                exit = fadeOut(),
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 8.dp)
            ) {
                bannerAlert?.let { alertText ->
                    Surface(
                        shape = RoundedCornerShape(24.dp),
                        color = BeerGold,
                        shadowElevation = 8.dp,
                        modifier = Modifier.clickable { squadViewModel.clearBanner() }
                    ) {
                        Text(
                            text = alertText,
                            color = Color.Black,
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.5.sp,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                        )
                    }
                }
            }
        }
    }

    if (showTrackerSheet) {
        val totalSquadDrinks = members.sumOf { it.drinksCount }
        val leader = members.maxByOrNull { it.drinksCount }

        ModalBottomSheet(
            onDismissRequest = { showTrackerSheet = false },
            containerColor = MaterialTheme.colorScheme.surface,
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Pivski Tracker Klape",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp,
                            color = Color.White
                        )
                        Text(
                            text = "Seznam vseh članov in število pijač",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    IconButton(onClick = { showTrackerSheet = false }) {
                        Icon(Icons.Default.Close, contentDescription = "Zapri", tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Povzetek kartica
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Skupaj popitih piv:", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("$totalSquadDrinks pijač", fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, color = BeerGold)
                        }
                        if (leader != null && leader.drinksCount > 0) {
                            Column(horizontalAlignment = Alignment.End) {
                                Text("Pivski vodja:", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text("${leader.name} (${leader.drinksCount})", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = Color.White)
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Seznam vseh članov
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(members) { member ->
                        val isMe = member.id == squadViewModel.myUserId
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = if (isMe) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .background(if (isMe) BeerGold else MaterialTheme.colorScheme.surfaceVariant, CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = member.name.take(1).uppercase(),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 15.sp,
                                        color = if (isMe) Color.Black else Color.White
                                    )
                                }

                                Spacer(modifier = Modifier.width(12.dp))

                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = if (isMe) "${member.name} (Ti)" else member.name,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp,
                                        color = Color.White
                                    )
                                    Text(
                                        text = if (isMe) "Tvoj profil" else "Član klape",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }

                                if (isMe) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Box(
                                            modifier = Modifier
                                                .size(28.dp)
                                                .clip(RoundedCornerShape(6.dp))
                                                .background(MaterialTheme.colorScheme.surfaceVariant)
                                                .clickable { squadViewModel.decrementDrinks() },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Text("-", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = Color.White)
                                        }

                                        Spacer(modifier = Modifier.width(6.dp))

                                        Text(
                                            text = "${member.drinksCount} pijač",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.5.sp,
                                            color = BeerGold
                                        )

                                        Spacer(modifier = Modifier.width(6.dp))

                                        Box(
                                            modifier = Modifier
                                                .size(28.dp)
                                                .clip(RoundedCornerShape(6.dp))
                                                .background(BeerGold)
                                                .clickable { squadViewModel.incrementDrinks() },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Icon(Icons.Default.Add, contentDescription = "+1", tint = Color.Black, modifier = Modifier.size(14.dp))
                                        }
                                    }
                                } else {
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = MaterialTheme.colorScheme.surfaceVariant
                                    ) {
                                        Text(
                                            text = "${member.drinksCount} pijač",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 12.sp,
                                            color = BeerGold,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Gumb Jaz častim rundo
                Button(
                    onClick = {
                        squadViewModel.sendQuickAction("Jaz častim naslednjo rundo za mizo!", "round_call")
                        showTrackerSheet = false
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = BeerGold)
                ) {
                    Icon(Icons.Default.SportsBar, contentDescription = null, tint = Color.Black)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Jaz častim naslednjo rundo!", fontWeight = FontWeight.Bold, color = Color.Black)
                }

                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun QuickActionChip(text: String, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = Modifier.clickable { onClick() }
    ) {
        Text(
            text = text,
            fontSize = 11.5.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
        )
    }
}

@Composable
private fun ChatMessageItem(message: SquadMessage, isMe: Boolean) {
    if (message.msgType == "system") {
        Box(
            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
            ) {
                Text(
                    text = message.content,
                    fontSize = 11.5.sp,
                    color = BeerGold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
                )
            }
        }
        return
    }

    val isSpecialAction = message.msgType in listOf("round_call", "eta")

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isMe) Alignment.End else Alignment.Start
    ) {
        if (!isMe) {
            Text(
                text = message.senderName,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = BeerGold,
                modifier = Modifier.padding(start = 6.dp, bottom = 2.dp)
            )
        }

        Surface(
            shape = RoundedCornerShape(
                topStart = 14.dp,
                topEnd = 14.dp,
                bottomStart = if (isMe) 14.dp else 2.dp,
                bottomEnd = if (isMe) 2.dp else 14.dp
            ),
            color = when {
                isSpecialAction -> BeerGold.copy(alpha = 0.25f)
                isMe -> BeerGold
                else -> MaterialTheme.colorScheme.surfaceVariant
            },
            border = if (isSpecialAction) androidx.compose.foundation.BorderStroke(1.dp, BeerGold) else null,
            modifier = Modifier.padding(horizontal = 2.dp)
        ) {
            Text(
                text = message.content,
                fontSize = 13.5.sp,
                color = if (isMe && !isSpecialAction) Color.Black else MaterialTheme.colorScheme.onSurface,
                fontWeight = if (isSpecialAction) FontWeight.Bold else FontWeight.Normal,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
            )
        }
    }
}

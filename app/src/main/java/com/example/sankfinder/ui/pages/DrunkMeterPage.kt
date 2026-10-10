package com.example.sankfinder.ui.pages

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalBar
import androidx.compose.material.icons.filled.LocalPhone
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.example.compose.BeerAmber
import com.example.compose.BeerDarkAmber
import com.example.compose.BeerFoamWhite
import com.example.compose.BeerGold
import com.example.compose.BeerLiquidBottom
import com.example.compose.DrajvGreen
import com.example.compose.DrajvRed
import com.example.sankfinder.ui.components.AppTopBar
import com.example.sankfinder.ui.navigation.BottomNavBar
import com.example.sankfinder.ui.navigation.Routes
import com.example.sankfinder.ui.viewmodels.DrunkViewModel
import kotlinx.coroutines.launch
import kotlin.math.sin

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrunkMeterPage(
    navController: NavHostController,
    viewModel: DrunkViewModel
) {
    val context = LocalContext.current
    val drinks by viewModel.drinks.collectAsState()
    val maxDrinks = viewModel.maxDrinks
    val targetFill = (drinks.toFloat() / maxDrinks).coerceIn(0f, 1f)

    // Smooth physics liquid animation
    val animatedFill by animateFloatAsState(
        targetValue = targetFill,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = 120f),
        label = "fillAnimation"
    )

    // Pour wave ripple trigger on new drinks
    var pourRipple by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(drinks) {
        if (drinks > 0) {
            pourRipple = 1f
        }
    }

    val infiniteTransition = rememberInfiniteTransition(label = "krigelLoop")
    val bubblePhase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1800, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "bubblePhase"
    )

    var showResetDialog by remember { mutableStateOf(false) }
    val water by viewModel.water.collectAsState()

    // BAC and status calculation
    val estimatedBac = drinks * 0.22f
    val soberHours = (drinks * 1.4f)
    val statusInfo = when {
        drinks == 0 -> Triple("Trezno", "0.00 ‰ • Varno za volan", DrajvGreen)
        drinks in 1..2 -> Triple("Za ogrevanje", String.format("%.2f ‰ • Dobra volja", estimatedBac), Color(0xFFFBBF24))
        drinks in 3..4 -> Triple("Pod gasom", String.format("%.2f ‰ • Klepetav, ne vozi več!", estimatedBac), Color(0xFFF97316))
        drinks in 5..6 -> Triple("Pripito", String.format("%.2f ‰ • Pevski zbor za šankom", estimatedBac), DrajvRed)
        drinks in 7..9 -> Triple("Šank bojevnik", String.format("%.2f ‰ • Pazi na ravnotežje!", estimatedBac), Color(0xFFA855F7))
        drinks in 10..12 -> Triple("Kralj šanka", String.format("%.2f ‰ • Legendarni status večera", estimatedBac), Color(0xFFD97706))
        drinks in 13..15 -> Triple("Vesoljski pilot", String.format("%.2f ‰ • Izguba zemeljske gravitacije", estimatedBac), Color(0xFF06B6D4))
        else -> Triple("Breztežnostno stanje", String.format("%.2f ‰ • Takoj v posteljo in veliko vode!", estimatedBac), Color(0xFFEC4899))
    }

    Scaffold(
        topBar = {
            AppTopBar(
                title = "Šank Meter",
                currentRoute = Routes.DRUNK,
                onNavigationClick = { navController.popBackStack() }
            )
        },
        bottomBar = { BottomNavBar(navController = navController) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // STATUS BADGE
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = statusInfo.third.copy(alpha = 0.12f)
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .background(statusInfo.third, CircleShape)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = statusInfo.first,
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = statusInfo.third
                                )
                            )
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = statusInfo.second,
                            style = MaterialTheme.typography.bodySmall.copy(
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        )
                    }

                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            text = "$drinks pijač",
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        )
                        Text(
                            text = if (drinks > 0) "Treznjenje: ~${String.format("%.1f", soberHours)} h" else "Trezno",
                            style = MaterialTheme.typography.labelSmall.copy(
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // THE KRIGEL (REALISTIC BEER MUG)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(290.dp),
                contentAlignment = Alignment.Center
            ) {
                // Subtle warm golden backlight glow
                Box(
                    modifier = Modifier
                        .size(200.dp)
                        .background(
                            brush = Brush.radialGradient(
                                colors = listOf(
                                    BeerGold.copy(alpha = 0.25f),
                                    Color.Transparent
                                )
                            ),
                            shape = CircleShape
                        )
                )

                BeerKrigelCanvas(
                    fillPercent = animatedFill,
                    bubblePhase = bubblePhase,
                    pourRipple = pourRipple,
                    modifier = Modifier.size(width = 230.dp, height = 270.dp)
                )
            }

            Spacer(modifier = Modifier.height(18.dp))

            // BIG PRIMARY "+1 PIVO" BUTTON
            Button(
                onClick = { viewModel.addDrink() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(58.dp)
                    .shadow(8.dp, RoundedCornerShape(18.dp)),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary
                )
            ) {
                Icon(
                    imageVector = Icons.Default.SportsBar,
                    contentDescription = null,
                    modifier = Modifier.size(26.dp)
                )
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = "+1 VELIKO PIVO (0.5 L)",
                    style = MaterialTheme.typography.titleMedium.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp
                    )
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            // SECONDARY ACTIONS ROW
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // +1 ŠILCE / SHOT
                OutlinedButton(
                    onClick = { viewModel.addDrink() },
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.LocalBar,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("+ Šilce", fontWeight = FontWeight.SemiBold)
                }

                // -1 DRINK
                OutlinedButton(
                    onClick = { viewModel.removeDrink() },
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(14.dp),
                    enabled = drinks > 0
                ) {
                    Icon(
                        imageVector = Icons.Default.Remove,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("-1", fontWeight = FontWeight.SemiBold)
                }

                // RESET
                OutlinedButton(
                    onClick = {
                        if (drinks > 0 || water > 0) showResetDialog = true
                    },
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(14.dp),
                    enabled = drinks > 0 || water > 0
                ) {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Reset", fontWeight = FontWeight.SemiBold)
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // SECTION 1: WATER HYDRATION TRACKER (VODNI BALANS)
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF0284C7).copy(alpha = 0.12f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Vodni balans in hidracija",
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF38BDF8)
                                )
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "1 pivo = 1 kozarec vode proti mačku",
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            )
                        }

                        Spacer(modifier = Modifier.width(12.dp))

                        Box(
                            modifier = Modifier
                                .background(Color(0xFF38BDF8).copy(alpha = 0.2f), RoundedCornerShape(10.dp))
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text(
                                text = "$water kozarcev",
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.ExtraBold,
                                    color = Color(0xFF38BDF8)
                                ),
                                maxLines = 1
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Button(
                            onClick = { viewModel.addWater() },
                            modifier = Modifier.weight(1f).height(44.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF0284C7),
                                contentColor = Color.White
                            )
                        ) {
                            Text("+1 Kozarec vode", fontWeight = FontWeight.Bold)
                        }

                        OutlinedButton(
                            onClick = { viewModel.removeWater() },
                            modifier = Modifier.height(44.dp),
                            shape = RoundedCornerShape(12.dp),
                            enabled = water > 0
                        ) {
                            Text("-1")
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // SECTION 2: EVENING METRICS & STATS
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Statistika večera",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "${drinks * 215} kcal",
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = BeerGold
                                )
                            )
                            Text(
                                text = "Energija (pivo)",
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontSize = 11.sp
                                )
                            )
                        }

                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = String.format("%.2f ‰", estimatedBac),
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = statusInfo.third
                                )
                            )
                            Text(
                                text = "Ocenjen BAC",
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontSize = 11.sp
                                )
                            )
                        }

                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "~${String.format("%.1f", soberHours)} h",
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            )
                            Text(
                                text = "Čas treznjenja",
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontSize = 11.sp
                                )
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // SECTION 3: NIVOJI IN LEGENDA ŠANKA (LADDER)
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Stopnje šankovskega mojstra",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Kje se nahajate po legendi šanka:",
                        style = MaterialTheme.typography.bodySmall.copy(
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    val levels = listOf(
                        Triple("Trezno", "0 pijač", drinks == 0),
                        Triple("Za ogrevanje", "1 - 2 pijači", drinks in 1..2),
                        Triple("Pod gasom", "3 - 4 pijače", drinks in 3..4),
                        Triple("Pripito", "5 - 6 pijač", drinks in 5..6),
                        Triple("Šank bojevnik", "7 - 9 pijač", drinks in 7..9),
                        Triple("Kralj šanka", "10 - 12 pijač", drinks in 10..12),
                        Triple("Vesoljski pilot", "13 - 15 pijač", drinks in 13..15),
                        Triple("Breztežnostno stanje", "16+ pijač", drinks >= 16)
                    )

                    levels.forEach { (name, desc, isActive) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    color = if (isActive) MaterialTheme.colorScheme.primary.copy(alpha = 0.2f) else Color.Transparent,
                                    shape = RoundedCornerShape(8.dp)
                                )
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = name,
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
                                    color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                                )
                            )
                            Text(
                                text = desc,
                                style = MaterialTheme.typography.labelSmall.copy(
                                    color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal
                                )
                            )
                        }
                    }
                }
            }

            // SAFE TAXI BUTTON (If drinks >= 3)
            if (drinks >= 3) {
                Spacer(modifier = Modifier.height(16.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = DrajvRed.copy(alpha = 0.12f)
                    )
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Čas za varno pot domov?",
                                style = MaterialTheme.typography.titleSmall.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = DrajvRed
                                )
                            )
                            Text(
                                text = "Alkohol upočasni reakcije. Ne sedajte za volan.",
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            )
                        }

                        Button(
                            onClick = {
                                val intent = Intent(Intent.ACTION_DIAL).apply {
                                    data = Uri.parse("tel:0801122")
                                }
                                context.startActivity(intent)
                            },
                            shape = RoundedCornerShape(10.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = DrajvRed,
                                contentColor = Color.White
                            )
                        ) {
                            Icon(
                                imageVector = Icons.Default.LocalPhone,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Taksi", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = { Text("Ponastavi meter?") },
            text = { Text("Ali želite število spitih pijač ponastaviti na 0?") },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.reset()
                        showResetDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = DrajvRed)
                ) {
                    Text("Ponastavi")
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Prekliči")
                }
            }
        )
    }
}

/**
 * Realistic Bavarian beer stein (krigel) with glass body, ribbed facets,
 * glass handle, animated carbonation bubbles, and creamy frothy foam top!
 */
@Composable
fun BeerKrigelCanvas(
    fillPercent: Float,
    bubblePhase: Float,
    pourRipple: Float,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height

        // Mug dimensions
        val mugW = w * 0.58f
        val mugH = h * 0.82f
        val mugL = (w - mugW) / 2f - 18f // offset slightly to leave room for handle on right
        val mugT = (h - mugH) / 2f + 4f
        val corner = 22f

        // Handle dimensions (right side)
        val handleW = mugW * 0.38f
        val handleH = mugH * 0.58f
        val handleL = mugL + mugW - 6f
        val handleT = mugT + mugH * 0.18f

        // 1. DRAW GLASS HANDLE (Back & Outer stroke)
        val handleOuterPath = Path().apply {
            moveTo(mugL + mugW - 8f, handleT)
            cubicTo(
                handleL + handleW + 16f, handleT - 4f,
                handleL + handleW + 16f, handleT + handleH + 4f,
                mugL + mugW - 8f, handleT + handleH
            )
        }
        drawPath(
            path = handleOuterPath,
            color = Color(0xFF64748B).copy(alpha = 0.5f),
            style = Stroke(width = 22f)
        )
        drawPath(
            path = handleOuterPath,
            color = Color.White.copy(alpha = 0.35f),
            style = Stroke(width = 8f)
        )

        // 2. BEER LIQUID FILL & FOAM
        val wallThickness = 12f
        val bottomBaseHeight = 24f
        val innerL = mugL + wallThickness
        val innerR = mugL + mugW - wallThickness
        val innerW = innerR - innerL
        val innerBottom = mugT + mugH - bottomBaseHeight
        val innerTop = mugT + 10f
        val totalInnerH = innerBottom - innerTop

        val currentLiquidHeight = totalInnerH * fillPercent
        val fillY = innerBottom - currentLiquidHeight

        // Clip beer inside the mug glass chamber
        clipRect(
            left = innerL,
            top = innerTop,
            right = innerR,
            bottom = innerBottom
        ) {
            if (fillPercent > 0.01f) {
                // Amber Liquid Gradient
                val liquidGradient = Brush.verticalGradient(
                    colors = listOf(
                        BeerGold,
                        BeerAmber,
                        BeerDarkAmber,
                        BeerLiquidBottom
                    ),
                    startY = fillY,
                    endY = innerBottom
                )

                // Draw Liquid Body
                drawRect(
                    brush = liquidGradient,
                    topLeft = Offset(innerL, fillY),
                    size = Size(innerW, innerBottom - fillY)
                )

                // Rising Carbonation Bubbles
                val bubbleCount = 14
                for (i in 0 until bubbleCount) {
                    val xRatio = (0.12f + (i * 0.065f)) % 1f
                    val bubbleX = innerL + xRatio * innerW + (sin((bubblePhase * 6.28f) + i) * 6f)
                    val progress = ((bubblePhase + (i * 0.07f)) % 1f)
                    val bubbleY = innerBottom - (progress * currentLiquidHeight)

                    if (bubbleY > fillY + 6f && bubbleY < innerBottom - 4f) {
                        val bubbleRadius = 2.5f + (i % 3) * 1.2f
                        drawCircle(
                            color = Color.White.copy(alpha = 0.65f),
                            radius = bubbleRadius,
                            center = Offset(bubbleX, bubbleY)
                        )
                    }
                }

                // Frothy Head of Foam (Smetana / Pena)
                val foamBaseHeight = (22f + (fillPercent * 24f)).coerceAtMost(46f)
                val foamTop = fillY - foamBaseHeight * 0.75f

                // Overlapping fluffy foam scalloped circles
                val scallopCount = 7
                val scallopWidth = innerW / (scallopCount - 1)
                for (s in 0 until scallopCount) {
                    val cx = innerL + s * scallopWidth
                    val cy = fillY - 4f
                    val r = (scallopWidth * 0.85f) + (sin(s * 1.5f) * 4f)
                    drawCircle(
                        color = BeerFoamWhite,
                        radius = r,
                        center = Offset(cx, cy)
                    )
                }

                // Smooth foam cap
                drawRoundRect(
                    color = BeerFoamWhite,
                    topLeft = Offset(innerL - 2f, foamTop),
                    size = Size(innerW + 4f, foamBaseHeight),
                    cornerRadius = CornerRadius(14f, 14f)
                )

                // Extra creamy micro-bubbles on top of foam
                for (b in 0..10) {
                    val bx = innerL + (b * (innerW / 10f))
                    val by = foamTop + (sin(b * 1.1f) * 4f)
                    drawCircle(
                        color = Color.White.copy(alpha = 0.9f),
                        radius = 4f,
                        center = Offset(bx, by)
                    )
                }
            }
        }

        // 3. KRIGEL GLASS BODY (Heavy Glass Contour, Facets & Base)

        // Glass Heavy Base
        drawRoundRect(
            brush = Brush.verticalGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.15f),
                    Color(0xFF64748B).copy(alpha = 0.35f)
                ),
                startY = innerBottom,
                endY = mugT + mugH
            ),
            topLeft = Offset(mugL, innerBottom),
            size = Size(mugW, bottomBaseHeight),
            cornerRadius = CornerRadius(corner, corner)
        )

        // Outer Glass Wall Stroke
        drawRoundRect(
            brush = Brush.horizontalGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.6f),
                    Color(0xFF64748B).copy(alpha = 0.3f),
                    Color.White.copy(alpha = 0.5f)
                ),
                startX = mugL,
                endX = mugL + mugW
            ),
            topLeft = Offset(mugL, mugT),
            size = Size(mugW, mugH),
            cornerRadius = CornerRadius(corner, corner),
            style = Stroke(width = wallThickness)
        )

        // Ribbed Glass Vertical Facets (Traditional Oktoberfest Stein Dimples)
        val facetCount = 4
        val facetSpacing = innerW / (facetCount + 1)
        for (f in 1..facetCount) {
            val fx = innerL + f * facetSpacing
            // Vertical reflection line
            drawLine(
                color = Color.White.copy(alpha = 0.32f),
                start = Offset(fx, mugT + 14f),
                end = Offset(fx, innerBottom - 6f),
                strokeWidth = 3f
            )
            drawLine(
                color = Color.Black.copy(alpha = 0.12f),
                start = Offset(fx + 3f, mugT + 14f),
                end = Offset(fx + 3f, innerBottom - 6f),
                strokeWidth = 2f
            )
        }

        // Left specular glass highlight (long vertical sheen)
        drawLine(
            brush = Brush.verticalGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.65f),
                    Color.White.copy(alpha = 0.2f),
                    Color.Transparent
                ),
                startY = mugT + 10f,
                endY = innerBottom
            ),
            start = Offset(innerL + 6f, mugT + 12f),
            end = Offset(innerL + 6f, innerBottom - 10f),
            strokeWidth = 5f
        )

        // Top glass rim highlight
        drawLine(
            color = Color.White.copy(alpha = 0.8f),
            start = Offset(mugL + 12f, mugT),
            end = Offset(mugL + mugW - 12f, mugT),
            strokeWidth = 4f
        )
    }
}


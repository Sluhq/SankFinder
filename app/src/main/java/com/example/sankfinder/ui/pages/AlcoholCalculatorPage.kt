package com.example.sankfinder.ui.pages

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.LocalPhone
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.example.compose.BeerGold
import com.example.compose.DrajvGreen
import com.example.compose.DrajvRed
import com.example.sankfinder.ui.components.AppTopBar
import com.example.sankfinder.ui.navigation.BottomNavBar
import com.example.sankfinder.ui.navigation.Routes
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import kotlin.math.cos
import kotlin.math.sin

data class DrinkPreset(
    val name: String,
    val volumeMl: Double,
    val alcoholPercent: Double
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AlcoholCalculatorPage(navController: NavController) {
    val context = LocalContext.current

    val presets = listOf(
        DrinkPreset("Veliko pivo", 500.0, 5.0),
        DrinkPreset("Malo pivo", 330.0, 5.0),
        DrinkPreset("Kozarec vina", 100.0, 12.0),
        DrinkPreset("Brizganec", 200.0, 6.5),
        DrinkPreset("Šilce žganja", 30.0, 40.0),
        DrinkPreset("Koktajl", 200.0, 15.0),
        DrinkPreset("Poljubno", 500.0, 5.0)
    )

    var selectedPreset by remember { mutableStateOf(presets[0]) }
    var quantity by remember { mutableIntStateOf(2) }
    var weightKg by remember { mutableFloatStateOf(75f) }
    var isMale by remember { mutableStateOf(true) }
    var hoursPassed by remember { mutableFloatStateOf(1.0f) }
    var hadFood by remember { mutableStateOf(true) }

    var customVolume by remember { mutableStateOf("500") }
    var customPercent by remember { mutableStateOf("5.0") }

    // Calculation using Widmark formula with hepatic elimination rate
    val (volMl, percent) = if (selectedPreset.name == "Poljubno") {
        (customVolume.toDoubleOrNull() ?: 500.0) to (customPercent.toDoubleOrNull() ?: 5.0)
    } else {
        selectedPreset.volumeMl to selectedPreset.alcoholPercent
    }

    // Widmark factor: Men ~0.70, Women ~0.60
    val r = if (isMale) 0.70 else 0.60
    // Food slows peak absorption slightly
    val foodFactor = if (hadFood) 0.88 else 1.0

    val totalAlcoholGrams = quantity * volMl * (percent / 100.0) * 0.789 * foodFactor
    val peakPromili = if (weightKg > 0) (totalAlcoholGrams / (r * weightKg)) else 0.0

    // Human liver metabolizes ~0.15 ‰ of alcohol per hour
    val eliminatedPromili = hoursPassed * 0.15
    val currentPromili = (peakPromili - eliminatedPromili).coerceAtLeast(0.0)

    val soberHoursNeeded = if (currentPromili > 0) (currentPromili / 0.15) else 0.0
    val soberTime = LocalTime.now().plusMinutes((soberHoursNeeded * 60).toLong())
    val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")

    Scaffold(
        topBar = {
            AppTopBar(
                title = "Alkoholno računalo",
                currentRoute = Routes.CALCULATOR,
                onNavigationClick = { navController.popBackStack() }
            )
        },
        bottomBar = { BottomNavBar(navController) }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 1. VISUAL BAC SPEEDOMETER GAUGE
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Ocenjena raven alkohola v krvi",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    BacSpeedometer(
                        promili = currentPromili.toFloat(),
                        modifier = Modifier.size(width = 240.dp, height = 145.dp)
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Driving Status Pill
                    val (statusText, statusDesc, statusColor) = when {
                        currentPromili <= 0.02 -> Triple(
                            "0.00 ‰ • Varno za volan",
                            "Trezno stanje. Vožnja je varna in dovoljena.",
                            DrajvGreen
                        )
                        currentPromili in 0.02..0.24 -> Triple(
                            "${String.format("%.2f", currentPromili)} ‰ • Dovoljeno za izkušene",
                            "Dovoljeno za splošne voznike B, 0.0 ‰ za začetnike in poklicne voznike.",
                            Color(0xFFEAB308)
                        )
                        currentPromili in 0.24..0.50 -> Triple(
                            "${String.format("%.2f", currentPromili)} ‰ • Mejna raven",
                            "Opaženo zmanjšanje zbranosti. Prepovedano za mlade voznike.",
                            Color(0xFFF97316)
                        )
                        currentPromili in 0.50..0.80 -> Triple(
                            "${String.format("%.2f", currentPromili)} ‰ • Prekršek (300 € + 4 točke)",
                            "Prepovedana vožnja po ZPrCP. Kazen 300 € in 4 kazenske točke.",
                            DrajvRed
                        )
                        currentPromili in 0.80..1.10 -> Triple(
                            "${String.format("%.2f", currentPromili)} ‰ • Hujši prekršek (600 € + 8 točk)",
                            "Bistveno upočasnjene reakcije. Kazen 600 € in 8 kazenskih točk.",
                            DrajvRed
                        )
                        else -> Triple(
                            "${String.format("%.2f", currentPromili)} ‰ • Odvzem izpita (1.200 € + 18 točk)",
                            "Takojšnje pridržanje policije, globa 1.200 € in prenehanje veljavnosti vozniškega dovoljenja.",
                            Color(0xFFDC2626)
                        )
                    }

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(statusColor.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                            .padding(horizontal = 14.dp, vertical = 10.dp)
                    ) {
                        Column {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .background(statusColor, CircleShape)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = statusText,
                                    style = MaterialTheme.typography.titleSmall.copy(
                                        fontWeight = FontWeight.Bold,
                                        color = statusColor
                                    )
                                )
                            }
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = statusDesc,
                                style = MaterialTheme.typography.bodySmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontSize = 11.5.sp
                                )
                            )
                        }
                    }

                    if (currentPromili > 0.05) {
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Predviden čas streznitve (0.00 ‰):",
                                style = MaterialTheme.typography.bodySmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
                            )
                            Text(
                                text = "~${String.format("%.1f", soberHoursNeeded)} h (ob ${soberTime.format(timeFormatter)})",
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            )
                        }
                    }
                }
            }

            // 2. IZBIRA PIJAČE (PRESET CHIPS)
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "1. Izberite pijačo",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                    )
                    Spacer(modifier = Modifier.height(10.dp))

                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        presets.forEach { preset ->
                            val isSelected = selectedPreset.name == preset.name
                            FilterChip(
                                selected = isSelected,
                                onClick = { selectedPreset = preset },
                                label = {
                                    Text(preset.name)
                                },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                                )
                            )
                        }
                    }

                    if (selectedPreset.name == "Poljubno") {
                        Spacer(modifier = Modifier.height(12.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            OutlinedTextField(
                                value = customVolume,
                                onValueChange = { customVolume = it },
                                label = { Text("Količina (ml)") },
                                modifier = Modifier.weight(1f),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                            )
                            OutlinedTextField(
                                value = customPercent,
                                onValueChange = { customPercent = it },
                                label = { Text("Alkohol (%)") },
                                modifier = Modifier.weight(1f),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                            )
                        }
                    } else {
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Standardna enota: ${selectedPreset.volumeMl.toInt()} ml • ${selectedPreset.alcoholPercent}% alkohola",
                            style = MaterialTheme.typography.bodySmall.copy(
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        )
                    }
                }
            }

            // 3. KOLIČINA & ČAS OD ZAČETKA
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "2. Količina in potek večera",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Stepper: Število pijač
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Število naročenih pijač",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold)
                            )
                            Text(
                                text = "${quantity * volMl.toInt()} ml skupaj",
                                style = MaterialTheme.typography.labelSmall.copy(
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            )
                        }

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(
                                onClick = { if (quantity > 1) quantity-- },
                                enabled = quantity > 1
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .background(MaterialTheme.colorScheme.surface, CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(imageVector = Icons.Default.Remove, contentDescription = null)
                                }
                            }

                            Text(
                                text = "$quantity",
                                style = MaterialTheme.typography.titleLarge.copy(
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary
                                ),
                                modifier = Modifier.padding(horizontal = 12.dp)
                            )

                            IconButton(onClick = { quantity++ }) {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .background(MaterialTheme.colorScheme.surface, CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(imageVector = Icons.Default.Add, contentDescription = null)
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Čas od prve pijače
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "Čas od prve pijače:",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold)
                        )
                        Text(
                            text = "${String.format("%.1f", hoursPassed)} h",
                            style = MaterialTheme.typography.bodyMedium.copy(
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        )
                    }

                    Slider(
                        value = hoursPassed,
                        onValueChange = { hoursPassed = it },
                        valueRange = 0f..8f,
                        steps = 15,
                        colors = SliderDefaults.colors(
                            thumbColor = MaterialTheme.colorScheme.primary,
                            activeTrackColor = MaterialTheme.colorScheme.primary
                        )
                    )
                }
            }

            // 4. TELESNE ZNAČILNOSTI (SPOL, TEŽA, HRANA)
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "3. Osebni podatki in absorpcija",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Gender toggle
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        FilterChip(
                            selected = isMale,
                            onClick = { isMale = true },
                            label = { Text("Moški (r = 0.70)") },
                            modifier = Modifier.weight(1f),
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = MaterialTheme.colorScheme.primary,
                                selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                            )
                        )
                        FilterChip(
                            selected = !isMale,
                            onClick = { isMale = false },
                            label = { Text("Ženska (r = 0.60)") },
                            modifier = Modifier.weight(1f),
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = MaterialTheme.colorScheme.primary,
                                selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Weight Slider
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "Telesna teža:",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold)
                        )
                        Text(
                            text = "${weightKg.toInt()} kg",
                            style = MaterialTheme.typography.bodyMedium.copy(
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        )
                    }

                    Slider(
                        value = weightKg,
                        onValueChange = { weightKg = it },
                        valueRange = 45f..130f,
                        steps = 84,
                        colors = SliderDefaults.colors(
                            thumbColor = MaterialTheme.colorScheme.primary,
                            activeTrackColor = MaterialTheme.colorScheme.primary
                        )
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    // Food Toggle
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        FilterChip(
                            selected = hadFood,
                            onClick = { hadFood = true },
                            label = { Text("Po obroku (počasneje)") },
                            modifier = Modifier.weight(1f)
                        )
                        FilterChip(
                            selected = !hadFood,
                            onClick = { hadFood = false },
                            label = { Text("Prazen želodec (hitreje)") },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            // TAXI BUTTON IF ALCOHOL DETECTED
            if (currentPromili > 0.05) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = DrajvRed.copy(alpha = 0.12f))
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
                                text = "Ne tvegaj za volanom!",
                                style = MaterialTheme.typography.titleSmall.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = DrajvRed
                                )
                            )
                            Text(
                                text = "Pokliči prevoz in se varno vrni domov.",
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

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

/**
 * Beautiful semi-circular speedometer gauge for Promili (BAC).
 * Features gradient arcs and smooth needle animation.
 */
@Composable
fun BacSpeedometer(
    promili: Float,
    modifier: Modifier = Modifier
) {
    val animatedPromili by animateFloatAsState(
        targetValue = promili.coerceIn(0f, 2.5f),
        animationSpec = tween(durationMillis = 600),
        label = "promiliSpeedometer"
    )

    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val center = Offset(w / 2f, h * 0.90f)
        val radius = w * 0.42f
        val strokeWidth = 24f

        // Draw track arc from 180° to 360°
        drawArc(
            color = Color(0xFF1E293B),
            startAngle = 180f,
            sweepAngle = 180f,
            useCenter = false,
            topLeft = Offset(center.x - radius, center.y - radius),
            size = Size(radius * 2, radius * 2),
            style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
        )

        // Draw active gradient arc
        // 0.00 -> 180°, 2.50 -> 360° (sweep = 180°)
        val activeSweep = (animatedPromili / 2.5f) * 180f
        val color = when {
            animatedPromili <= 0.24f -> DrajvGreen
            animatedPromili <= 0.50f -> Color(0xFFEAB308)
            animatedPromili <= 1.10f -> Color(0xFFF97316)
            else -> DrajvRed
        }

        if (activeSweep > 0f) {
            drawArc(
                color = color,
                startAngle = 180f,
                sweepAngle = activeSweep.coerceIn(2f, 180f),
                useCenter = false,
                topLeft = Offset(center.x - radius, center.y - radius),
                size = Size(radius * 2, radius * 2),
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )
        }

        // Draw needle
        val angleRad = Math.toRadians((180f + activeSweep).toDouble())
        val needleLength = radius * 0.78f
        val needleEnd = Offset(
            (center.x + needleLength * cos(angleRad)).toFloat(),
            (center.y + needleLength * sin(angleRad)).toFloat()
        )

        drawLine(
            color = Color.White,
            start = center,
            end = needleEnd,
            strokeWidth = 6f,
            cap = StrokeCap.Round
        )

        // Center pivot circle
        drawCircle(
            color = color,
            radius = 12f,
            center = center
        )
        drawCircle(
            color = Color.White,
            radius = 6f,
            center = center
        )
    }
}

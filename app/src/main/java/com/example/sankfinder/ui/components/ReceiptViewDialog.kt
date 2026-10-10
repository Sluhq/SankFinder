package com.example.sankfinder.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.compose.BeerGold
import com.example.sankfinder.data.VisitHistory
import java.time.format.DateTimeFormatter

/**
 * Authentic Slovenian thermal cash register receipt ("Davčni račun")
 * displaying detailed line items, FURS QR code, ZOI/EOR, and totals.
 */
@Composable
fun ReceiptViewDialog(
    visit: VisitHistory,
    onDismiss: () -> Unit
) {
    val dateFormatter = DateTimeFormatter.ofPattern("dd. MM. yyyy 'ob' HH:mm:ss")
    val receiptNumber = "RAČ-2026-${(visit.visitedAt.minute * 17 + visit.drinks).toString().padStart(5, '0')}"

    // Parse items from note if available, otherwise generate authentic items
    val items: List<Pair<String, Double>> = rememberReceiptItems(visit)

    val ddvRate = 0.22
    val ddvAmount = visit.amountSpent * (ddvRate / (1.0 + ddvRate))
    val osnovaAmount = visit.amountSpent - ddvAmount

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            Button(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary
                )
            ) {
                Text("Zapri račun", fontWeight = FontWeight.Bold)
            }
        },
        title = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Receipt,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Davčni račun",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                    )
                }
                IconButton(onClick = onDismiss) {
                    Icon(imageVector = Icons.Default.Close, contentDescription = "Zapri")
                }
            }
        },
        text = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFFF8FAFC), RoundedCornerShape(12.dp))
                    .border(1.dp, Color(0xFFCBD5E1), RoundedCornerShape(12.dp))
                    .padding(14.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // RECEIPT HEADER
                    Text(
                        text = "ŠANKFINDER SISTEM",
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = Color.Black
                    )
                    Text(
                        text = visit.lokal.name.uppercase(),
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 15.sp,
                        color = Color.Black,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        text = visit.lokal.address,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                        color = Color(0xFF475569),
                        textAlign = TextAlign.Center
                    )
                    Text(
                        text = "ID za DDV: SI 82947192",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 10.5.sp,
                        color = Color(0xFF64748B)
                    )

                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "- - - - - - - - - - - - - - - - - - - -",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 10.sp,
                        color = Color(0xFF94A3B8)
                    )
                    Spacer(modifier = Modifier.height(4.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "Št. računa:",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 11.sp,
                            color = Color.Black
                        )
                        Text(
                            text = receiptNumber,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            color = Color.Black
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "Datum:",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = Color(0xFF475569)
                        )
                        Text(
                            text = visit.visitedAt.format(dateFormatter),
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = Color(0xFF475569)
                        )
                    }

                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "==================================",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 10.sp,
                        color = Color(0xFF94A3B8)
                    )

                    // ITEMS LIST
                    items.forEach { (itemTitle, itemPrice) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 2.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = itemTitle,
                                fontFamily = FontFamily.Monospace,
                                fontSize = 11.sp,
                                color = Color.Black,
                                modifier = Modifier.weight(1f)
                            )
                            Text(
                                text = "${String.format("%.2f", itemPrice)} €",
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 11.sp,
                                color = Color.Black
                            )
                        }
                    }

                    Text(
                        text = "----------------------------------",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 10.sp,
                        color = Color(0xFF94A3B8)
                    )

                    // TOTAL AND TAX
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "SKUPAJ ZA PLAČILO:",
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 13.sp,
                            color = Color.Black
                        )
                        Text(
                            text = "${String.format("%.2f", visit.amountSpent)} €",
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 14.sp,
                            color = Color.Black
                        )
                    }

                    Spacer(modifier = Modifier.height(4.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "Osnova (22%):",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = Color(0xFF64748B)
                        )
                        Text(
                            text = "${String.format("%.2f", osnovaAmount)} €",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = Color(0xFF64748B)
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "DDV (22%):",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = Color(0xFF64748B)
                        )
                        Text(
                            text = "${String.format("%.2f", ddvAmount)} €",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = Color(0xFF64748B)
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "Način plačila:",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = Color(0xFF64748B)
                        )
                        Text(
                            text = "GOTOVINA",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = Color(0xFF64748B)
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "==================================",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 10.sp,
                        color = Color(0xFF94A3B8)
                    )

                    // FURS QR CODE & VALIDATION INFO (Samo če je račun dejansko imel FURS QR kodo)
                    val hasFursQr = visit.note?.contains("[FURS QR]") == true || visit.note?.contains("FURS QR") == true
                    if (hasFursQr) {
                        Spacer(modifier = Modifier.height(4.dp))
                        FursQrCodeGraphic(modifier = Modifier.size(90.dp))
                        Spacer(modifier = Modifier.height(6.dp))

                        Text(
                            text = "ZOI: 4f82a9c17b3d2e054a8b",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 9.sp,
                            color = Color(0xFF64748B)
                        )
                        Text(
                            text = "EOR: 8a73b2c1-d4e5-4f6a-8b9c-123456789abc",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 8.5.sp,
                            color = Color(0xFF64748B)
                        )
                        Text(
                            text = "Davčno potrjen račun (FURS RS)",
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 9.sp,
                            color = Color(0xFF16A34A)
                        )
                    } else {
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Optično prebrano z računa (OCR)",
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Medium,
                            fontSize = 9.5.sp,
                            color = Color(0xFF475569)
                        )
                        Text(
                            text = "Račun nima davčne QR kode",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 8.5.sp,
                            color = Color(0xFF94A3B8)
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Hvala za obisk!",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.Black
                    )
                }
            }
        }
    )
}

/**
 * Authentic thermal QR code graphic drawing corner anchor squares and pseudo-random data matrix.
 */
@Composable
fun FursQrCodeGraphic(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val size = size.width
        val cellSize = size / 21f

        // Draw background
        drawRect(color = Color.White)

        // Helper to draw a filled QR module
        fun drawModule(col: Int, row: Int) {
            drawRect(
                color = Color.Black,
                topLeft = Offset(col * cellSize, row * cellSize),
                size = Size(cellSize, cellSize)
            )
        }

        // Draw the 3 finder corner squares (top-left, top-right, bottom-left)
        fun drawFinder(startCol: Int, startRow: Int) {
            for (r in 0 until 7) {
                for (c in 0 until 7) {
                    if (r == 0 || r == 6 || c == 0 || c == 6) {
                        drawModule(startCol + c, startRow + r)
                    } else if (r in 2..4 && c in 2..4) {
                        drawModule(startCol + c, startRow + r)
                    }
                }
            }
        }

        drawFinder(0, 0)
        drawFinder(14, 0)
        drawFinder(0, 14)

        // Draw timing lines
        for (i in 8..12) {
            if (i % 2 == 0) {
                drawModule(6, i)
                drawModule(i, 6)
            }
        }

        // Draw realistic data modules pattern
        val pattern = listOf(
            8 to 2, 8 to 4, 10 to 1, 12 to 3, 9 to 8, 11 to 9, 13 to 8,
            8 to 14, 8 to 16, 10 to 18, 12 to 20, 14 to 8, 16 to 10,
            15 to 15, 17 to 17, 19 to 15, 15 to 19, 18 to 18, 20 to 14,
            14 to 12, 16 to 14, 18 to 12, 10 to 14, 11 to 15, 12 to 14,
            9 to 11, 11 to 11, 13 to 11, 7 to 8, 7 to 12, 13 to 13
        )
        pattern.forEach { (c, r) -> drawModule(c, r) }
    }
}

/**
 * Returns a realistic itemized receipt bill based on note or total drinks/amount.
 */
private fun rememberReceiptItems(visit: VisitHistory): List<Pair<String, Double>> {
    val note = visit.note
    if (note != null && (note.contains("Skenirano z računa") || note.contains("Prebrano z računa"))) {
        val colonIdx = note.indexOf(':')
        val raw = if (colonIdx != -1) note.substring(colonIdx + 1).trim() else note
        val parts = raw.split("\n", ",").map { it.trim() }.filter { it.isNotEmpty() }
        if (parts.isNotEmpty()) {
            return parts.map { part ->
                val price = extractPriceFromItem(part)
                part to price
            }
        }
    }

    // Default authentic item generation matching visit
    val drinks = maxOf(1, visit.drinks)
    val avgPrice = if (drinks > 0 && visit.amountSpent > 0.0) visit.amountSpent / drinks else 3.80

    return when (drinks) {
        1 -> listOf("1x Točeno pivo 0.5L" to visit.amountSpent)
        2 -> listOf(
            "1x Točeno pivo 0.5L" to avgPrice,
            "1x Laško Zlatorog 0.5L" to (visit.amountSpent - avgPrice)
        )
        3 -> listOf(
            "2x Točeno pivo Union 0.5L" to (avgPrice * 2),
            "1x Pelinkovec Antique 0.03L" to (visit.amountSpent - avgPrice * 2)
        )
        else -> listOf(
            "${drinks - 1}x Točeno pivo 0.5L" to (avgPrice * (drinks - 1)),
            "1x Prigrizek & mineralna" to (visit.amountSpent - avgPrice * (drinks - 1))
        )
    }
}

private fun extractPriceFromItem(item: String): Double {
    val regex = """\(([\d.]+)\s*€\)""".toRegex()
    val match = regex.find(item)
    return match?.groupValues?.get(1)?.toDoubleOrNull() ?: 3.50
}

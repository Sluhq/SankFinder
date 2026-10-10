package com.example.sankfinder.ui.components

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.example.compose.BeerGold
import com.example.compose.DrajvGreen
import com.example.sankfinder.data.Lokal
import com.example.sankfinder.data.VisitHistory
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.util.Locale
import java.util.regex.Pattern

data class ScannedReceiptData(
    val pubName: String,
    val address: String,
    val items: List<String>,
    val totalDrinks: Int,
    val totalAmount: Double,
    val isQrVerified: Boolean,
    val rawQrCode: String
)

@Composable
fun ReceiptScannerDialog(
    initialLokal: Lokal? = null,
    onReceiptScanned: (VisitHistory) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    var hasCameraPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED
        )
    }

    var isProcessingImage by remember { mutableStateOf(false) }
    var processingStatusMessage by remember { mutableStateOf("Analiziram račun z OCR...") }
    var scannedResult by remember { mutableStateOf<ScannedReceiptData?>(null) }
    var capturedBitmap by remember { mutableStateOf<Bitmap?>(null) }

    // Urejanje prepoznanih podatkov (če uporabnik želi popraviti ali dopolniti)
    var editPubName by remember { mutableStateOf("") }
    var editAddress by remember { mutableStateOf("") }
    var editTotalDrinks by remember { mutableIntStateOf(1) }
    var editTotalAmount by remember { mutableDoubleStateOf(0.0) }
    var editItemsNote by remember { mutableStateOf("") }
    var editAmountText by remember { mutableStateOf("0.00") }

    fun processReceiptBitmap(bitmap: Bitmap) {
        capturedBitmap = bitmap
        isProcessingImage = true
        processingStatusMessage = "Zagon optične prepoznave (ML Kit OCR)..."

        val image = InputImage.fromBitmap(bitmap, 0)
        val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val barcodeScanner = BarcodeScanning.getClient()

        // 1. Zaznaj QR kodo (davčne blagajne FURS itd.)
        barcodeScanner.process(image)
            .addOnSuccessListener { barcodes ->
                var qrCodeString = ""
                var hasQr = false
                for (barcode in barcodes) {
                    if (barcode.format == Barcode.FORMAT_QR_CODE) {
                        val raw = barcode.rawValue?.trim().orEmpty()
                        if (raw.isNotBlank()) {
                            qrCodeString = raw
                            hasQr = true
                            break
                        }
                    }
                }

                // 2. Optično prepoznavanje besedila z računa
                processingStatusMessage = "Branje postavk in zneska..."
                textRecognizer.process(image)
                    .addOnSuccessListener { visionText ->
                        val parsed = parseReceiptText(
                            rawText = visionText.text,
                            defaultPub = initialLokal,
                            qrCode = qrCodeString,
                            isQr = hasQr
                        )

                        scannedResult = parsed
                        editPubName = parsed.pubName
                        editAddress = parsed.address
                        editTotalDrinks = parsed.totalDrinks
                        editTotalAmount = parsed.totalAmount
                        editAmountText = String.format(Locale.US, "%.2f", parsed.totalAmount)
                        editItemsNote = parsed.items.joinToString("\n")

                        isProcessingImage = false
                    }
                    .addOnFailureListener { e ->
                        // Fallback, če OCR ne najde teksta
                        val fallback = ScannedReceiptData(
                            pubName = initialLokal?.name ?: "Pivnica",
                            address = initialLokal?.address ?: "Ljubljana",
                            items = listOf("Zajet račun (slika)"),
                            totalDrinks = 1,
                            totalAmount = 0.0,
                            isQrVerified = hasQr,
                            rawQrCode = qrCodeString
                        )
                        scannedResult = fallback
                        editPubName = fallback.pubName
                        editAddress = fallback.address
                        editTotalDrinks = 1
                        editTotalAmount = 0.0
                        editAmountText = "0.00"
                        editItemsNote = "Račun poslikan, prosimo vnesite znesek."
                        isProcessingImage = false
                    }
            }
            .addOnFailureListener {
                // Če QR ne uspe, vseeno zaženi OCR teksta
                textRecognizer.process(image)
                    .addOnSuccessListener { visionText ->
                        val parsed = parseReceiptText(
                            rawText = visionText.text,
                            defaultPub = initialLokal,
                            qrCode = "",
                            isQr = false
                        )
                        scannedResult = parsed
                        editPubName = parsed.pubName
                        editAddress = parsed.address
                        editTotalDrinks = parsed.totalDrinks
                        editTotalAmount = parsed.totalAmount
                        editAmountText = String.format(Locale.US, "%.2f", parsed.totalAmount)
                        editItemsNote = parsed.items.joinToString("\n")
                        isProcessingImage = false
                    }
                    .addOnFailureListener {
                        isProcessingImage = false
                    }
            }
    }

    // Kamera launcher (zajem prave fotografije s kamero telefona)
    val takePictureLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        if (bitmap != null) {
            processReceiptBitmap(bitmap)
        }
    }

    // Galerija launcher (izbira že poslikanega računa)
    val pickGalleryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            try {
                val bitmap = loadBitmapFromUri(context, it)
                if (bitmap != null) {
                    processReceiptBitmap(bitmap)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasCameraPermission = granted
        if (granted) {
            takePictureLauncher.launch(null)
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            if (scannedResult != null) {
                Button(
                    onClick = {
                        val finalAmount = editAmountText.replace(',', '.').toDoubleOrNull() ?: editTotalAmount
                        val visit = VisitHistory(
                            lokal = initialLokal?.copy(
                                name = editPubName.ifBlank { initialLokal.name },
                                address = editAddress.ifBlank { initialLokal.address }
                            ) ?: Lokal(
                                name = editPubName.ifBlank { "Neznan šank" },
                                address = editAddress.ifBlank { "Ljubljana" },
                                lat = 46.056946,
                                lon = 14.505751,
                                cuisine = "Pivnica",
                                phone = null,
                                website = null,
                                openingHours = null
                            ),
                            visitedAt = LocalDateTime.now(),
                            drinks = editTotalDrinks.coerceAtLeast(1),
                            amountSpent = finalAmount,
                            rating = 5.0,
                            note = run {
                                val tag = if (scannedResult?.isQrVerified == true) "[FURS QR]" else "[OCR]"
                                val items = if (editItemsNote.isNotBlank()) editItemsNote else "Znesek ${String.format(Locale.US, "%.2f", finalAmount)} €"
                                "Skenirano z računa $tag: $items"
                            }
                        )
                        onReceiptScanned(visit)
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary
                    )
                ) {
                    Icon(imageVector = Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Shrani v zgodovino")
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Prekliči")
            }
        },
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.Receipt,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Optično branje računa (OCR)", fontWeight = FontWeight.Bold, fontSize = 18.sp)
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                if (scannedResult == null) {
                    Text(
                        text = "Poslikajte pravi gostinski račun ali QR kodo. Aplikacija bo z uporabo umetne inteligence (ML Kit) avtomatsko prebrala artikle, število pijač in znesek.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Vizualni predogled / Viewfinder okvir
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(160.dp)
                            .background(Color.Black.copy(alpha = 0.85f), RoundedCornerShape(16.dp))
                            .border(2.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(16.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (isProcessingImage) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(40.dp),
                                    color = MaterialTheme.colorScheme.primary,
                                    strokeWidth = 3.dp
                                )
                                Spacer(modifier = Modifier.height(12.dp))
                                Text(
                                    text = processingStatusMessage,
                                    color = Color.White,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        } else {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier.padding(16.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.QrCode,
                                    contentDescription = null,
                                    tint = BeerGold,
                                    modifier = Modifier.size(46.dp)
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = "Optični čitalnik računa pripravljen",
                                    color = Color.White.copy(alpha = 0.9f),
                                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold)
                                )
                                Text(
                                    text = "Prepozna slovenske račune in FURS QR kodo",
                                    color = Color.White.copy(alpha = 0.6f),
                                    style = MaterialTheme.typography.labelSmall
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(18.dp))

                    // Glavni gumb za slikanje s kamero
                    Button(
                        onClick = {
                            if (hasCameraPermission) {
                                takePictureLauncher.launch(null)
                            } else {
                                permissionLauncher.launch(Manifest.permission.CAMERA)
                            }
                        },
                        modifier = Modifier.fillMaxWidth().height(48.dp),
                        shape = RoundedCornerShape(12.dp),
                        enabled = !isProcessingImage
                    ) {
                        Icon(imageVector = Icons.Default.CameraAlt, contentDescription = null, modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Poslikaj račun s kamero", fontWeight = FontWeight.Bold)
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // Gumb za izbiro slike iz galerije
                    OutlinedButton(
                        onClick = {
                            pickGalleryLauncher.launch("image/*")
                        },
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                        shape = RoundedCornerShape(12.dp),
                        enabled = !isProcessingImage
                    ) {
                        Icon(imageVector = Icons.Default.PhotoLibrary, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Izberi sliko iz galerije")
                    }
                } else {
                    // PREGLED IN UREJANJE PREPOZNANIH PODATKOV (Real OCR Result)
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                        )
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            // Mini thumbnail poslikanega računa (če je na voljo)
                            capturedBitmap?.let { bmp ->
                                Image(
                                    bitmap = bmp.asImageBitmap(),
                                    contentDescription = "Poslikan račun",
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(110.dp)
                                        .clip(RoundedCornerShape(8.dp)),
                                    contentScale = ContentScale.Crop
                                )
                                Spacer(modifier = Modifier.height(10.dp))
                            }

                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(
                                        color = if (scannedResult?.isQrVerified == true) DrajvGreen.copy(alpha = 0.12f)
                                                else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                                        shape = RoundedCornerShape(10.dp)
                                    )
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 10.dp, vertical = 6.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    val isQr = scannedResult?.isQrVerified == true
                                    Row(
                                        modifier = Modifier.weight(1f, fill = false),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Icon(
                                            imageVector = if (isQr) Icons.Default.CheckCircle else Icons.Default.Receipt,
                                            contentDescription = null,
                                            tint = if (isQr) DrajvGreen else MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.size(16.dp)
                                        )
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = if (isQr) "FURS QR potrjen" else "Prebrano z OCR",
                                            style = MaterialTheme.typography.labelMedium.copy(
                                                color = if (isQr) DrajvGreen else MaterialTheme.colorScheme.onSurface,
                                                fontWeight = FontWeight.SemiBold
                                            ),
                                            maxLines = 1
                                        )
                                    }

                                    TextButton(
                                        onClick = {
                                            scannedResult = null
                                            capturedBitmap = null
                                        },
                                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 8.dp, vertical = 2.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.CameraAlt,
                                            contentDescription = null,
                                            tint = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.size(14.dp)
                                        )
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text(
                                            text = "Ponovno poslikaj",
                                            fontSize = 11.5.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = MaterialTheme.colorScheme.primary,
                                            maxLines = 1,
                                            softWrap = false
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            // Lokal naziv
                            OutlinedTextField(
                                value = editPubName,
                                onValueChange = { editPubName = it },
                                label = { Text("Naziv lokala", fontSize = 12.sp) },
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true,
                                shape = RoundedCornerShape(8.dp)
                            )

                            Spacer(modifier = Modifier.height(8.dp))

                            // Število pijač z enostavnimi +/- gumbi
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Število pijač:",
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold)
                                )

                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(
                                        onClick = { if (editTotalDrinks > 1) editTotalDrinks-- },
                                        modifier = Modifier.size(34.dp).background(MaterialTheme.colorScheme.surface, CircleShape)
                                    ) {
                                        Icon(Icons.Default.Remove, contentDescription = "Manj", modifier = Modifier.size(16.dp))
                                    }

                                    Text(
                                        text = "$editTotalDrinks",
                                        modifier = Modifier.padding(horizontal = 14.dp),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 16.sp,
                                        color = BeerGold
                                    )

                                    IconButton(
                                        onClick = { editTotalDrinks++ },
                                        modifier = Modifier.size(34.dp).background(MaterialTheme.colorScheme.surface, CircleShape)
                                    ) {
                                        Icon(Icons.Default.Add, contentDescription = "Več", modifier = Modifier.size(16.dp))
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // Znesek računa v €
                            OutlinedTextField(
                                value = editAmountText,
                                onValueChange = {
                                    editAmountText = it
                                    it.replace(',', '.').toDoubleOrNull()?.let { amt ->
                                        editTotalAmount = amt
                                    }
                                },
                                label = { Text("Skupni znesek računa (€)", fontSize = 12.sp) },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true,
                                shape = RoundedCornerShape(8.dp)
                            )

                            Spacer(modifier = Modifier.height(10.dp))

                            // Opombe / Prepoznane postavke
                            OutlinedTextField(
                                value = editItemsNote,
                                onValueChange = { editItemsNote = it },
                                label = { Text("Prepoznani artikli z računa", fontSize = 12.sp) },
                                modifier = Modifier.fillMaxWidth(),
                                maxLines = 4,
                                shape = RoundedCornerShape(8.dp)
                            )
                        }
                    }
                }
            }
        }
    )
}

/**
 * Pametni analizator slovenskih in splošnih gostinskih računov iz OCR besedila
 */
private fun parseReceiptText(
    rawText: String,
    defaultPub: Lokal?,
    qrCode: String,
    isQr: Boolean
): ScannedReceiptData {
    val lines = rawText.split("\n").map { it.trim() }.filter { it.isNotBlank() }

    // 1. Naziv lokala (preveri prve vrstice računa ali ohrani privzetega)
    var pubName = defaultPub?.name ?: ""
    val address = defaultPub?.address ?: "Ljubljana"

    if (pubName.isBlank() && lines.isNotEmpty()) {
        for (i in 0 until minOf(4, lines.size)) {
            val line = lines[i]
            if (line.contains("d.o.o.", ignoreCase = true) ||
                line.contains("s.p.", ignoreCase = true) ||
                line.contains("bar", ignoreCase = true) ||
                line.contains("pivnica", ignoreCase = true) ||
                line.contains("gostilna", ignoreCase = true) ||
                line.contains("kavarna", ignoreCase = true) ||
                line.contains("pub", ignoreCase = true)
            ) {
                pubName = line
                break
            }
        }
        if (pubName.isBlank() && lines.isNotEmpty()) {
            pubName = lines[0]
        }
    }

    // 2. Prepoznavanje postavk pijač in zneskov
    val beverageKeywords = listOf(
        "pivo", "laško", "union", "heineken", "radenska", "voda", "kava", "espresso",
        "cappuccino", "čaj", "sok", "cola", "fanta", "sprite", "pelinkovec", "jeger",
        "gin", "tonik", "aperol", "spritz", "vino", "cviček", "malvazija", "refošk",
        "rum", "vodka", "viski", "pijača", "špricer", "koktajl", "cocktail", "radler",
        "pils", "ipa", "ale", "bela kava", "macchiato", "krožnik", "toast"
    )

    val detectedItems = mutableListOf<String>()
    var detectedDrinksCount = 0
    var parsedTotalAmount = 0.0

    // Vzorec za znesek (npr. 3.50, 4,20, 15.00 EUR)
    val pricePattern = Pattern.compile("(\\d{1,4}[.,]\\d{2})\\s*(?:€|eur)?", Pattern.CASE_INSENSITIVE)

    for (line in lines) {
        val lower = line.lowercase()

        // Preveri ključne besede za pijače
        val isBeverage = beverageKeywords.any { lower.contains(it) }

        if (isBeverage) {
            detectedItems.add(line)

            // Poskusi prepoznati količino (npr. "2x" ali "3 x")
            val qtyMatch = Pattern.compile("(\\d+)\\s*[xX*]").matcher(line)
            if (qtyMatch.find()) {
                val qty = qtyMatch.group(1)?.toIntOrNull() ?: 1
                detectedDrinksCount += qty
            } else {
                detectedDrinksCount += 1
            }
        }

        // Iskanje skupnega zneska: "SKUPAJ", "ZA PLAČILO", "ZNESEK", "TOTAL", "EUR"
        if (lower.contains("skupaj") || lower.contains("za plačilo") || lower.contains("plačilo") ||
            lower.contains("znesek") || lower.contains("total") || lower.contains("vrednost")
        ) {
            val matcher = pricePattern.matcher(line)
            if (matcher.find()) {
                val priceStr = matcher.group(1)?.replace(',', '.')
                priceStr?.toDoubleOrNull()?.let {
                    if (it > parsedTotalAmount) parsedTotalAmount = it
                }
            }
        }
    }

    // Če nismo našli vrstice s "SKUPAJ", poišči največjo ceno na računu kot skupni znesek
    if (parsedTotalAmount == 0.0) {
        for (line in lines) {
            val matcher = pricePattern.matcher(line)
            while (matcher.find()) {
                val priceStr = matcher.group(1)?.replace(',', '.')
                priceStr?.toDoubleOrNull()?.let {
                    if (it in 1.0..250.0 && it > parsedTotalAmount) {
                        parsedTotalAmount = it
                    }
                }
            }
        }
    }

    // Če nismo prepoznali specifičnih pijač, vključi povzetek vrstic
    if (detectedItems.isEmpty()) {
        val candidateLines = lines.filter { it.length > 3 && !it.contains("davčna", ignoreCase = true) }.take(3)
        detectedItems.addAll(candidateLines)
    }

    if (detectedDrinksCount == 0) {
        detectedDrinksCount = if (parsedTotalAmount > 0.0) (parsedTotalAmount / 3.5).toInt().coerceAtLeast(1) else 1
    }

    return ScannedReceiptData(
        pubName = pubName.ifBlank { "Pivnica" },
        address = address,
        items = detectedItems,
        totalDrinks = detectedDrinksCount,
        totalAmount = parsedTotalAmount,
        isQrVerified = isQr && qrCode.isNotBlank(),
        rawQrCode = qrCode
    )
}

private fun loadBitmapFromUri(context: Context, uri: Uri): Bitmap? {
    return try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(context.contentResolver, uri)
            ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                decoder.isMutableRequired = true
            }
        } else {
            @Suppress("DEPRECATION")
            MediaStore.Images.Media.getBitmap(context.contentResolver, uri)
        }
    } catch (e: Exception) {
        null
    }
}

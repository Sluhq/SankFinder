package com.example.sankfinder.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.text.input.KeyboardType
import com.example.sankfinder.data.Lokal
import com.example.sankfinder.data.VisitHistory
import kotlinx.coroutines.launch
import java.time.LocalDateTime

@Composable
fun VisitDetailsDialog(
    lokal: Lokal,
    initialVisit: VisitHistory? = null,
    onConfirm: (VisitHistory) -> Unit,
    onDismiss: () -> Unit
) {
    var drinks by remember {
        mutableStateOf(
            initialVisit?.drinks?.takeIf { it > 0 }?.toString() ?: ""
        )
    }
    var amount by remember {
        mutableStateOf(
            initialVisit?.amountSpent?.takeIf { it > 0.0 }?.toString() ?: ""
        )
    }
    var rating by remember {
        mutableStateOf(
            initialVisit?.rating?.takeIf { it > 0.0 }?.toString() ?: ""
        )
    }
    var note by remember { mutableStateOf(initialVisit?.note ?: "") }

    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            Button(onClick = {
                val ratingValue = rating.toDoubleOrNull()
                if (ratingValue != null && (ratingValue < 0.0 || ratingValue > 5.0)) {
                    coroutineScope.launch {
                        snackbarHostState.showSnackbar("Ocena mora biti med 0 in 5.")
                    }
                    return@Button
                }

                val visit = VisitHistory(
                    lokal = lokal,
                    visitedAt = initialVisit?.visitedAt ?: LocalDateTime.now(),
                    drinks = drinks.toIntOrNull() ?: 0,
                    amountSpent = amount.toDoubleOrNull() ?: 0.0,
                    rating = ratingValue,
                    note = note.ifBlank { null }
                )
                onConfirm(visit)
            }) {
                Text("Shrani obisk")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Prekliči")
            }
        },
        title = {
            Text(if (initialVisit != null) "Uredi obisk" else "Dodaj podrobnosti obiska")
        },
        text = {
            Column {
                OutlinedTextField(
                    value = drinks,
                    onValueChange = { drinks = it },
                    label = { Text("Število pijač") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it },
                    label = { Text("Znesek (€)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
                OutlinedTextField(
                    value = rating,
                    onValueChange = { rating = it },
                    label = { Text("Ocena") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                )
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("Opomba") }
                )
                SnackbarHost(hostState = snackbarHostState)
            }
        }
    )
}

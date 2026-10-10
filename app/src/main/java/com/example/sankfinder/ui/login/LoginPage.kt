package com.example.sankfinder.ui.login

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.sankfinder.ui.theme.AppTheme

@Composable
fun LoginPage(onLoginSuccess: () -> Unit = {}) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Text("Prijava", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(16.dp))

        TextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("Uporabniško ime") },
            isError = error != null && username.isBlank(),
            singleLine = true,
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Text,
                imeAction = ImeAction.Next,
                autoCorrect = false
            )
        )

        Spacer(Modifier.height(8.dp))

        TextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Geslo") },
            visualTransformation = PasswordVisualTransformation(),
            isError = error != null && password.isBlank(),
            singleLine = true,
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Password,
                imeAction = ImeAction.Done,
                autoCorrect = false
            )
        )

        Spacer(Modifier.height(16.dp))

        Button(onClick = {
            error = when {
                username.isBlank() || password.isBlank() -> "Polja ne smejo biti prazna."
                username != "admin" -> "Napačno uporabniško ime."
                password != "123456" -> "Napačno geslo."
                else -> null
            }
            if (error == null) onLoginSuccess()
        }) {
            Text("Prijavi se")
        }

        error?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = MaterialTheme.colorScheme.error)
        }
    }
}

@Preview(showBackground = true)
@Composable
fun LoginPagePreviewLight() {
    AppTheme(darkTheme = false) {
        LoginPage()
    }
}

@Preview(showBackground = true)
@Composable
fun LoginPagePreviewDark() {
    AppTheme(darkTheme = true) {
        LoginPage()
    }
}

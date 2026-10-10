package com.example.sankfinder.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.layout.RowScope
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.example.sankfinder.ui.navigation.Routes

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppTopBar(
    title: String,
    currentRoute: String? = null,
    modifier: Modifier = Modifier,
    show: Boolean = true,
    onNavigationClick: () -> Unit = {},
    customNavigationIcon: (@Composable () -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {}
) {
    val showBackButton = currentRoute != null &&
            currentRoute != Routes.MAIN &&
            currentRoute != Routes.DRUNK &&
            currentRoute != Routes.CALCULATOR &&
            currentRoute != Routes.HISTORY &&
            currentRoute != Routes.SETTINGS

    AnimatedVisibility(
        visible = show,
        enter = fadeIn()
    ) {
        CenterAlignedTopAppBar(
            title = {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge.copy(
                        fontWeight = FontWeight.Bold
                    )
                )
            },
            navigationIcon = {
                if (customNavigationIcon != null) {
                    customNavigationIcon()
                } else if (showBackButton) {
                    IconButton(onClick = onNavigationClick) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Nazaj",
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            },
            actions = actions,
            modifier = modifier,
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                containerColor = MaterialTheme.colorScheme.surface,
                titleContentColor = MaterialTheme.colorScheme.onSurface,
                navigationIconContentColor = MaterialTheme.colorScheme.onSurface,
                actionIconContentColor = MaterialTheme.colorScheme.primary
            )
        )
    }
}


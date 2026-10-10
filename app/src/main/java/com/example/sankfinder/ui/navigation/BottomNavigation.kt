package com.example.sankfinder.ui.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.FormatListBulleted
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import androidx.navigation.compose.currentBackStackEntryAsState
import com.example.compose.BeerGold

@Composable
fun BottomNavBar(navController: NavController) {
    // 5 simetričnih zavihkov z Zemljevidom natanko na sredini (Glavni zavihek)
    val items = listOf(
        BottomNavItem("Šanki", Icons.AutoMirrored.Filled.FormatListBulleted, Routes.LIST),
        BottomNavItem("Orodja", Icons.Default.Build, Routes.GAMES),
        BottomNavItem("Zemljevid", Icons.Default.Map, Routes.MAIN),
        BottomNavItem("Zgodovina", Icons.Default.History, Routes.HISTORY),
        BottomNavItem("Nastavitve", Icons.Default.Settings, Routes.SETTINGS)
    )

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(12.dp, RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp)),
        shape = RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 3.dp
    ) {
        androidx.compose.foundation.layout.Column {
            HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.25f),
                thickness = 0.5.dp
            )
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                tonalElevation = 0.dp,
                windowInsets = NavigationBarDefaults.windowInsets,
                modifier = Modifier.navigationBarsPadding()
            ) {
                items.forEach { item ->
                    val isCenter = item.route == Routes.MAIN
                    val selected = currentRoute == item.route

                    NavigationBarItem(
                        selected = selected,
                        alwaysShowLabel = true,
                        onClick = {
                            if (currentRoute != item.route) {
                                navController.navigate(item.route) {
                                    popUpTo(navController.graph.startDestinationId) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        },
                        icon = {
                            if (isCenter) {
                                // Prefinjen osrednji gumb z umerjeno velikostjo in pivsko zlato obrobo
                                Box(
                                    modifier = Modifier
                                        .size(38.dp)
                                        .background(
                                            color = if (selected) BeerGold.copy(alpha = 0.22f)
                                                    else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                            shape = CircleShape
                                        )
                                        .border(
                                            width = if (selected) 1.5.dp else 1.dp,
                                            color = if (selected) BeerGold else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
                                            shape = CircleShape
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = item.icon,
                                        contentDescription = item.label,
                                        tint = if (selected) BeerGold else MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            } else {
                                Icon(
                                    imageVector = item.icon,
                                    contentDescription = item.label,
                                    modifier = Modifier.size(22.dp)
                                )
                            }
                        },
                        label = {
                            Text(
                                text = item.label,
                                fontSize = 10.sp,
                                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                                maxLines = 1,
                                softWrap = false,
                                color = if (selected) {
                                    if (isCenter) BeerGold else MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f)
                                }
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.primary,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            indicatorColor = if (isCenter) Color.Transparent else MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f),
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f)
                        )
                    )
                }
            }
        }
    }
}

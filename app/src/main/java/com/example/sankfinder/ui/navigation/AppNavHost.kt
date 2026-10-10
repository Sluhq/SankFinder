package com.example.sankfinder.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.example.sankfinder.datastore.ThemeDataStore
import com.example.sankfinder.ui.login.LoginPage
import com.example.sankfinder.ui.pages.AlcoholCalculatorPage
import com.example.sankfinder.ui.pages.DrunkMeterPage
import com.example.sankfinder.ui.pages.HistoryPage
import com.example.sankfinder.ui.pages.MainPage
import com.example.sankfinder.ui.pages.SettingsPage
import com.example.sankfinder.ui.viewmodels.DrunkViewModel

@Composable
fun AppNavHost(
    navController: NavHostController,
    themeDataStore: ThemeDataStore,
    startDestination: String = Routes.SPLASH
) {
    val lokalViewModel: com.example.sankfinder.ui.viewmodels.LokalViewModel = viewModel()
    val mapNavViewModel: com.example.sankfinder.ui.viewmodels.MapNavigationViewModel = viewModel()
    val squadViewModel: com.example.sankfinder.ui.viewmodels.SquadViewModel = viewModel()

    val savedLimit by themeDataStore.lokalLimit.collectAsState(initial = 20)
    LaunchedEffect(savedLimit) {
        lokalViewModel.setPreferredLimit(savedLimit, forceRefresh = false)
    }

    // Samodejno sinhroniziraj GPS koordinate v Pivsko Klapo (Squad Live Radar)
    val userLocation by mapNavViewModel.userLocation.collectAsState()
    LaunchedEffect(userLocation) {
        userLocation?.let { loc ->
            squadViewModel.updateMyLocation(loc.latitude, loc.longitude)
        }
    }

    // Poročaj o trenutnem zaslonu v skrbniško nadzorno ploščo
    LaunchedEffect(navController) {
        navController.currentBackStackEntryFlow.collect { backStackEntry ->
            val route = backStackEntry.destination.route ?: return@collect
            val friendlyName = when (route) {
                Routes.MAIN -> "Zemljevid & Šanki"
                Routes.LIST -> "Seznam lokalov"
                Routes.GAMES -> "Pivske igre"
                Routes.SQUAD -> "Pivska Klapa"
                Routes.DRUNK -> "Pivski števec"
                Routes.CALCULATOR -> "Kalkulator promilov"
                Routes.HISTORY -> "Zgodovina obiskov"
                Routes.SETTINGS -> "Nastavitve"
                else -> route
            }
            com.example.sankfinder.network.GlobalSyncManager.reportScreen(friendlyName)
        }
    }

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable(Routes.SPLASH) {
            com.example.sankfinder.ui.pages.SplashScreen(navController = navController)
        }
        composable(Routes.MAIN) {
            com.example.sankfinder.ui.pages.MapMainPage(
                navController = navController,
                lokalViewModel = lokalViewModel,
                mapNavViewModel = mapNavViewModel,
                squadViewModel = squadViewModel
            )
        }
        composable(Routes.LIST) {
            MainPage(
                navController = navController,
                viewModel = lokalViewModel,
                mapNavViewModel = mapNavViewModel,
                onNavigationClick = { }
            )
        }
        composable(Routes.GAMES) {
            com.example.sankfinder.ui.pages.GamesPage(
                navController = navController,
                lokalViewModel = lokalViewModel,
                mapNavViewModel = mapNavViewModel,
                squadViewModel = squadViewModel
            )
        }
        composable(Routes.SQUAD) {
            com.example.sankfinder.ui.pages.SquadPage(
                navController = navController,
                squadViewModel = squadViewModel
            )
        }
        composable(Routes.DRUNK) {
            val drunkViewModel: DrunkViewModel = viewModel()
            DrunkMeterPage(
                navController = navController,
                viewModel = drunkViewModel
            )
        }
        composable(Routes.CALCULATOR) {
            AlcoholCalculatorPage(navController = navController)
        }
        composable(Routes.HISTORY) {
            HistoryPage(navController = navController)
        }
        composable(Routes.SETTINGS) {
            SettingsPage(
                navController = navController,
                themeDataStore = themeDataStore
            )
        }
    }
}

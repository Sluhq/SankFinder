package com.example.sankfinder.ui.viewmodels

import android.location.Location
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.sankfinder.data.Lokal
import com.example.sankfinder.data.OsrmRoute
import com.example.sankfinder.data.OsrmRouteResponse
import com.example.sankfinder.data.OsrmStep
import com.example.sankfinder.network.OsrmApi
import com.example.sankfinder.network.OsrmFallbackApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import org.osmdroid.util.GeoPoint

class MapNavigationViewModel : ViewModel() {

    private val _userLocation = MutableStateFlow<Location?>(null)
    val userLocation: StateFlow<Location?> = _userLocation

    private val _userHeading = MutableStateFlow(0f)
    val userHeading: StateFlow<Float> = _userHeading

    private val _selectedLokal = MutableStateFlow<Lokal?>(null)
    val selectedLokal: StateFlow<Lokal?> = _selectedLokal

    private val _isNavigating = MutableStateFlow(false)
    val isNavigating: StateFlow<Boolean> = _isNavigating

    private val _isLoadingRoute = MutableStateFlow(false)
    val isLoadingRoute: StateFlow<Boolean> = _isLoadingRoute

    private val _activeRoute = MutableStateFlow<OsrmRoute?>(null)
    val activeRoute: StateFlow<OsrmRoute?> = _activeRoute

    private val _routePoints = MutableStateFlow<List<GeoPoint>>(emptyList())
    val routePoints: StateFlow<List<GeoPoint>> = _routePoints

    private val _currentStepIndex = MutableStateFlow(0)
    val currentStepIndex: StateFlow<Int> = _currentStepIndex

    private val _distanceToNextStepMeters = MutableStateFlow(0.0)
    val distanceToNextStepMeters: StateFlow<Double> = _distanceToNextStepMeters

    private val _remainingDistanceMeters = MutableStateFlow(0.0)
    val remainingDistanceMeters: StateFlow<Double> = _remainingDistanceMeters

    private val _remainingDurationSeconds = MutableStateFlow(0.0)
    val remainingDurationSeconds: StateFlow<Double> = _remainingDurationSeconds

    private val _hasArrived = MutableStateFlow(false)
    val hasArrived: StateFlow<Boolean> = _hasArrived

    private val _routeErrorMessage = MutableStateFlow<String?>(null)
    val routeErrorMessage: StateFlow<String?> = _routeErrorMessage

    private var isUserMoving = false
    private var pendingNavigationDestination: Lokal? = null

    fun setSelectedLokal(lokal: Lokal?) {
        _selectedLokal.value = lokal
    }

    fun setUserHeading(heading: Float, force: Boolean = false) {
        // Če se uporabnik premika in imamo zanesljiv GPS bearing, senzor ne sme povzročati trzanja
        if (!force && isUserMoving) return
        _userHeading.value = heading
    }

    fun onLocationUpdated(location: Location) {
        _userLocation.value = location

        // Če se uporabnik premika (hitrost > 0.6 m/s oz. ~2.2 km/h) in ima veljaven GPS bearing
        if (location.hasSpeed() && location.speed >= 0.6f && location.hasBearing() && location.bearing != 0f) {
            isUserMoving = true
            _userHeading.value = location.bearing
        } else if (location.hasSpeed() && location.speed < 0.35f) {
            isUserMoving = false
        }

        // Če je bil poslan zahtevek za navigacijo, medtem ko še nismo imeli lokacije, ga sedaj zaženemo
        if (pendingNavigationDestination != null) {
            val dest = pendingNavigationDestination!!
            pendingNavigationDestination = null
            startNavigation(dest)
        }

        // Če je navigacija aktivna, posodobi napredek
        if (_isNavigating.value) {
            checkNavigationProgress(location)
        }
    }

    fun startNavigation(destination: Lokal) {
        _selectedLokal.value = destination
        val userLoc = _userLocation.value
        if (userLoc == null) {
            pendingNavigationDestination = destination
            _isLoadingRoute.value = true
            return
        }
        pendingNavigationDestination = null
        viewModelScope.launch {
            _isLoadingRoute.value = true
            _routeErrorMessage.value = null
            val coords = "${userLoc.longitude},${userLoc.latitude};${destination.lon},${destination.lat}"
            Log.d("MapNavigationVM", "Kličem OSRM z koordinatami: $coords")

            var routeResponse: OsrmRouteResponse? = null

            // 1. Poskusi primarni OSRM strežnik (lastni strežnik)
            try {
                val res = OsrmApi.retrofitService.getFootRoute(coordinates = coords)
                if (res.code == "Ok" && res.routes.isNotEmpty()) {
                    routeResponse = res
                } else {
                    Log.w("MapNavigationVM", "Primarni OSRM vrnil kodo: ${res.code}")
                }
            } catch (e: Exception) {
                Log.w("MapNavigationVM", "Primarni OSRM ni uspel (${e.message}), poskušam rezervni strežnik...")
            }

            // 2. Če primarni strežnik ne deluje (npr. HTTP 530 ali nedosegljivost), samodejno poskusi uradni rezervni strežnik
            if (routeResponse == null) {
                try {
                    val res = OsrmFallbackApi.retrofitService.getFootRoute(coordinates = coords)
                    if (res.code == "Ok" && res.routes.isNotEmpty()) {
                        routeResponse = res
                        Log.i("MapNavigationVM", "Uspešno pridobljena pot prek rezervnega OSRM strežnika!")
                    }
                } catch (e: Exception) {
                    Log.e("MapNavigationVM", "Tudi rezervni OSRM strežnik ni uspel: ${e.message}", e)
                }
            }

            if (routeResponse != null && routeResponse.routes.isNotEmpty()) {
                val route = routeResponse.routes.first()
                _activeRoute.value = route

                // Pretvori GeoJSON koordinate [lon, lat] v GeoPoint(lat, lon)
                val points = route.geometry?.coordinates?.map { coord ->
                    GeoPoint(coord[1], coord[0])
                } ?: emptyList()

                _routePoints.value = points
                _remainingDistanceMeters.value = route.distance
                _remainingDurationSeconds.value = route.duration
                _currentStepIndex.value = 0
                _hasArrived.value = false
                _isNavigating.value = true

                val steps = route.legs.firstOrNull()?.steps ?: emptyList()
                if (steps.isNotEmpty()) {
                    _distanceToNextStepMeters.value = steps[0].distance
                }
            } else {
                _routeErrorMessage.value = "Navigacijska pot trenutno ni dosegljiva. Preverite internetno povezavo."
            }
            _isLoadingRoute.value = false
        }
    }

    fun stopNavigation() {
        _isNavigating.value = false
        _activeRoute.value = null
        _routePoints.value = emptyList()
        _currentStepIndex.value = 0
        _hasArrived.value = false
        _routeErrorMessage.value = null
    }

    private fun checkNavigationProgress(location: Location) {
        val route = _activeRoute.value ?: return
        val steps = route.legs.firstOrNull()?.steps ?: return
        val dest = _selectedLokal.value ?: return

        // 1. Preveri razdaljo do končnega cilja
        val destLocation = Location("dest").apply {
            latitude = dest.lat
            longitude = dest.lon
        }
        val distToGoal = location.distanceTo(destLocation).toDouble()
        _remainingDistanceMeters.value = distToGoal
        // Predviden preostali čas pri hitrosti pešca ~1.2 m/s
        _remainingDurationSeconds.value = distToGoal / 1.25

        if (distToGoal <= 15.0) {
            _hasArrived.value = true
            return
        }

        // 2. Preveri korak v navodilih za zavoje (usmerjanje proti prihajajočemu manevru)
        val currIdx = _currentStepIndex.value
        val upcomingIdx = currIdx + 1

        if (upcomingIdx < steps.size) {
            val upcomingStep = steps[upcomingIdx]
            val upcomingLoc = upcomingStep.maneuver?.location
            if (upcomingLoc != null && upcomingLoc.size >= 2) {
                val upcomingTarget = Location("upcoming").apply {
                    latitude = upcomingLoc[1]
                    longitude = upcomingLoc[0]
                }
                val distToUpcoming = location.distanceTo(upcomingTarget).toDouble()
                _distanceToNextStepMeters.value = distToUpcoming

                // Preveri ali smo naslednji ovinek že dosegli (znotraj 18m)
                var shouldAdvance = distToUpcoming <= 18.0

                // Dodatno preveri ali smo že zavili in smo bližje naslednjemu koraku (odpravi zastekanost)
                if (!shouldAdvance && upcomingIdx + 1 < steps.size) {
                    val nextNextLoc = steps[upcomingIdx + 1].maneuver?.location
                    if (nextNextLoc != null && nextNextLoc.size >= 2) {
                        val nextNextTarget = Location("nextNext").apply {
                            latitude = nextNextLoc[1]
                            longitude = nextNextLoc[0]
                        }
                        val distToNextNext = location.distanceTo(nextNextTarget).toDouble()
                        val stepDistance = upcomingStep.distance
                        if (distToNextNext < stepDistance * 0.85 && distToUpcoming < 35.0) {
                            shouldAdvance = true
                        }
                    }
                }

                if (shouldAdvance) {
                    _currentStepIndex.value = upcomingIdx
                    // Nemudoma posodobi razdaljo do novega naslednjega manevra
                    val newUpcoming = getCurrentStep()
                    val newLoc = newUpcoming?.maneuver?.location
                    if (newLoc != null && newLoc.size >= 2) {
                        val newTarget = Location("newTarget").apply {
                            latitude = newLoc[1]
                            longitude = newLoc[0]
                        }
                        _distanceToNextStepMeters.value = location.distanceTo(newTarget).toDouble()
                    }
                }
            }
        } else {
            _distanceToNextStepMeters.value = distToGoal
        }
    }

    fun getCurrentStep(): OsrmStep? {
        val steps = _activeRoute.value?.legs?.firstOrNull()?.steps ?: return null
        if (steps.isEmpty()) return null
        val idx = _currentStepIndex.value
        // Vedno vrni prihajajoči manever (ovinek pred nami), ali ciljni korak ob koncu
        return if (idx + 1 < steps.size) steps[idx + 1] else steps.last()
    }
}

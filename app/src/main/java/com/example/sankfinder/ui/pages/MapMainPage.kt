package com.example.sankfinder.ui.pages

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color as AndroidColor
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.net.Uri
import android.view.MotionEvent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.automirrored.filled.FormatListBulleted
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.BookmarkAdded
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.SportsBar
import androidx.compose.material.icons.filled.TurnLeft
import androidx.compose.material.icons.filled.TurnRight
import androidx.compose.material.icons.filled.TurnSharpLeft
import androidx.compose.material.icons.filled.TurnSharpRight
import androidx.compose.material.icons.filled.TurnSlightLeft
import androidx.compose.material.icons.filled.TurnSlightRight
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.example.compose.BeerGold
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.example.sankfinder.data.Lokal
import com.example.sankfinder.location.LocationManager
import com.example.sankfinder.ui.components.ReceiptScannerDialog
import com.example.sankfinder.ui.map.MapMarkerUtils
import com.example.sankfinder.ui.navigation.BottomNavBar
import com.example.sankfinder.ui.navigation.Routes
import com.example.sankfinder.ui.viewmodels.LokalViewModel
import com.example.sankfinder.ui.viewmodels.MapNavigationViewModel
import com.example.sankfinder.ui.viewmodels.VisitHistoryViewModel
import kotlinx.coroutines.launch
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline

@Composable
fun MapMainPage(
    navController: NavController,
    lokalViewModel: LokalViewModel = viewModel(),
    mapNavViewModel: MapNavigationViewModel = viewModel(),
    historyViewModel: VisitHistoryViewModel = viewModel(),
    squadViewModel: com.example.sankfinder.ui.viewmodels.SquadViewModel = viewModel()
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    val themeDataStore = remember { com.example.sankfinder.datastore.ThemeDataStore(context) }
    val savedRadius by themeDataStore.searchRadius.collectAsState(initial = 2000)
    val savedLimit by themeDataStore.lokalLimit.collectAsState(initial = 20)

    val lokali by lokalViewModel.lokali.collectAsState()
    val userLocation by mapNavViewModel.userLocation.collectAsState()
    val userHeading by mapNavViewModel.userHeading.collectAsState()
    val selectedLokal by mapNavViewModel.selectedLokal.collectAsState()
    val isNavigating by mapNavViewModel.isNavigating.collectAsState()
    val isLoadingRoute by mapNavViewModel.isLoadingRoute.collectAsState()
    val routePoints by mapNavViewModel.routePoints.collectAsState()
    val remainingDistance by mapNavViewModel.remainingDistanceMeters.collectAsState()
    val remainingDuration by mapNavViewModel.remainingDurationSeconds.collectAsState()
    val distanceToNextStep by mapNavViewModel.distanceToNextStepMeters.collectAsState()
    val hasArrived by mapNavViewModel.hasArrived.collectAsState()
    val routeError by mapNavViewModel.routeErrorMessage.collectAsState()

    val squadMembers by squadViewModel.members.collectAsState()
    val activeSquadRoom by squadViewModel.activeRoom.collectAsState()
    val squadMarkersRef = remember { mutableListOf<Marker>() }

    var lokalForReceiptScan by remember { mutableStateOf<Lokal?>(null) }
    var userMarkerRef by remember { mutableStateOf<Marker?>(null) }
    var routeCasingPolylineRef by remember { mutableStateOf<Polyline?>(null) }
    var routePolylineRef by remember { mutableStateOf<Polyline?>(null) }
    var maneuverMarkerRef by remember { mutableStateOf<Marker?>(null) }
    val pubMarkersRef = remember { mutableListOf<Marker>() }
    var mapOrientationDeg by remember { mutableFloatStateOf(0f) }
    var isTrackingUser by remember { mutableStateOf(true) }

    // Enkratno ustvarjen in ohranjen MapView za stabilno delovanje brez NPE
    val mapView = remember {
        val osmdroidConfig = org.osmdroid.config.Configuration.getInstance()
        val customUserAgent = "SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)"
        osmdroidConfig.userAgentValue = customUserAgent
        osmdroidConfig.userAgentHttpHeader = "User-Agent"

        MapView(context).apply {
            setTileSource(org.osmdroid.tileprovider.tilesource.TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            setTilesScaledToDpi(true)
            setDestroyMode(false)
            setBuiltInZoomControls(false) // Onemogoči grde privzete bele gumbe!
            controller.setZoom(16.0)
            controller.setCenter(GeoPoint(46.0569, 14.5058))

            // Omogoči 2-prstno rotacijo zemljevida
            val rotationOverlay = org.osmdroid.views.overlay.gestures.RotationGestureOverlay(this)
            rotationOverlay.isEnabled = true
            overlays.add(rotationOverlay)

            // Posodobi mapOrientationDeg in zaznaj ročni premik karte med navigacijo
            var touchDownX = 0f
            var touchDownY = 0f
            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        touchDownX = event.x
                        touchDownY = event.y
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = kotlin.math.abs(event.x - touchDownX)
                        val dy = kotlin.math.abs(event.y - touchDownY)
                        if ((dx > 25f || dy > 25f) && isNavigating && isTrackingUser) {
                            isTrackingUser = false
                        }
                    }
                }
                if (kotlin.math.abs(mapOrientation - mapOrientationDeg) > 0.5f) {
                    mapOrientationDeg = mapOrientation
                }
                false
            }

            addMapListener(object : org.osmdroid.events.MapListener {
                override fun onScroll(event: org.osmdroid.events.ScrollEvent?): Boolean {
                    mapOrientationDeg = mapOrientation
                    return false
                }
                override fun onZoom(event: org.osmdroid.events.ZoomEvent?): Boolean {
                    mapOrientationDeg = mapOrientation
                    return false
                }
            })
        }
    }

    // Varno ustvarjanje Markerja, ki nikoli ne zruši aplikacije
    fun createMarkerSafe(map: MapView): Marker? {
        return try {
            Marker(map)
        } catch (e: Throwable) {
            android.util.Log.e("MapMainPage", "Varno ujeta napaka pri Marker: ${e.message}")
            null
        }
    }

    // Upravljanje življenjskega cikla zemljevida (onResume / onPause)
    DisposableEffect(mapView) {
        mapView.onResume()
        onDispose {
            mapView.onPause()
        }
    }

    // Prikaz prijaznih opozoril (ni interneta itd.)
    val lokalWarning by lokalViewModel.warningMessage.collectAsState()
    LaunchedEffect(lokalWarning) {
        lokalWarning?.let { msg ->
            snackbarHostState.showSnackbar(msg)
            lokalViewModel.dismissWarning()
        }
    }

    // Ob napaki pri OSRM izpiši prijazno opozorilo
    LaunchedEffect(routeError) {
        routeError?.let { msg ->
            snackbarHostState.showSnackbar(msg)
        }
    }

    // Live GPS in senzor kompasa s stabilizacijo za hojo
    DisposableEffect(Unit) {
        val locationManager = LocationManager(context as Activity)
        locationManager.zahtevajDovoljenjeLokacije()

        locationManager.zacniSledenjeLokacije(intervalMs = 1000L) { loc ->
            mapNavViewModel.onLocationUpdated(loc)
            // Če še nimamo lokalov, osvežimo okoli prve lokacije
            if (lokali.isEmpty()) {
                lokalViewModel.fetchLokali(loc.latitude, loc.longitude, radius = savedRadius, limit = savedLimit)
            }
        }

        // Kompas senzor z remappingom koordinatnega sistema za naravno držanje telefona
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val sensorListener = object : SensorEventListener {
            val rotationMatrix = FloatArray(9)
            val remappedMatrix = FloatArray(9)
            val orientation = FloatArray(3)
            var lastUpdateMs = 0L
            var smoothedHeading = 0f

            override fun onSensorChanged(event: SensorEvent) {
                if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
                    val now = System.currentTimeMillis()
                    if (now - lastUpdateMs < 120) return // ~8 fps je stabilno in varčno z energijo

                    SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                    // Preusmeri osi za naravno držanje telefona v roki (portrait tilt)
                    SensorManager.remapCoordinateSystem(
                        rotationMatrix,
                        SensorManager.AXIS_X,
                        SensorManager.AXIS_Z,
                        remappedMatrix
                    )
                    SensorManager.getOrientation(remappedMatrix, orientation)
                    val rawAzimuth = Math.toDegrees(orientation[0].toDouble()).toFloat()
                    val normalized = (rawAzimuth + 360f) % 360f

                    // Gladko krožno filtriranje (odpravlja preklapljanje desno/dol med hojo)
                    val diff = ((normalized - smoothedHeading + 540f) % 360f) - 180f
                    smoothedHeading = (smoothedHeading + diff * 0.25f + 360f) % 360f

                    lastUpdateMs = now
                    mapNavViewModel.setUserHeading(smoothedHeading)
                }
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        rotationSensor?.let {
            sensorManager.registerListener(sensorListener, it, SensorManager.SENSOR_DELAY_NORMAL)
        }

        onDispose {
            locationManager.ustaviSledenjeLokacije()
            sensorManager.unregisterListener(sensorListener)
        }
    }

    // Preklop navigacijskega načina: samodejna orientacija v smeri hoje in osredotočenje (Google Maps slog)
    LaunchedEffect(isNavigating) {
        if (isNavigating) {
            isTrackingUser = true
            val loc = userLocation
            if (loc != null) {
                val targetGeo = GeoPoint(loc.latitude, loc.longitude)
                mapView.controller.setZoom(18.5)
                mapView.controller.animateTo(targetGeo)
            }
            val initialBearing = mapNavViewModel.getRouteWalkingBearing() ?: 0f
            val orientation = (360f - (initialBearing % 360f)) % 360f
            mapView.mapOrientation = orientation
            mapOrientationDeg = orientation
            mapView.postInvalidate()
        } else {
            isTrackingUser = true
            mapView.mapOrientation = 0f
            mapOrientationDeg = 0f
            mapView.postInvalidate()
        }
    }

    // Sprotno posodabljanje smeri kompasa na modri piki uporabnika
    LaunchedEffect(userHeading, mapOrientationDeg) {
        userMarkerRef?.let { marker ->
            marker.rotation = -(userHeading + mapView.mapOrientation)
            mapView.postInvalidate()
        }
    }

    // Posodobitev položaja modre pikice uporabnika z gladko animacijo hoje in stabilnim sledenjem v smeri hoje
    LaunchedEffect(userLocation, isNavigating, isTrackingUser) {
        val loc = userLocation ?: return@LaunchedEffect
        val targetGeo = GeoPoint(loc.latitude, loc.longitude)

        val marker = userMarkerRef ?: createMarkerSafe(mapView)?.also { newMarker ->
            newMarker.position = targetGeo
            newMarker.icon = MapMarkerUtils.createUserMarkerDrawable(context)
            newMarker.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
            newMarker.title = "Moja lokacija"
            newMarker.setInfoWindow(null)
            mapView.overlays.add(newMarker)
            userMarkerRef = newMarker
            mapView.controller.setCenter(targetGeo)
            mapView.controller.setZoom(if (isNavigating) 18.5 else 16.5)
        }

        // Če je sledenje vklopljeno, kamera zvezno sledi uporabniku v središču
        if (isTrackingUser) {
            mapView.controller.animateTo(targetGeo)
            if (isNavigating) {
                // STABILNA SMER HOJE VZDOLŽ TRASE - brez tresenja ali nihanja kompasa telefona!
                val walkingBearing = mapNavViewModel.getRouteWalkingBearing()
                if (walkingBearing != null) {
                    val targetOrientation = (360f - (walkingBearing % 360f)) % 360f
                    val currentOrientation = mapView.mapOrientation
                    val diff = ((targetOrientation - currentOrientation + 540f) % 360f) - 180f
                    if (kotlin.math.abs(diff) > 3.0f) {
                        mapView.mapOrientation = targetOrientation
                        mapOrientationDeg = targetOrientation
                    }
                }
            }
        }

        if (marker != null && marker.position != null) {
            marker.rotation = -(userHeading + mapView.mapOrientation)

            val startLat = marker.position.latitude
            val startLon = marker.position.longitude
            val deltaLat = targetGeo.latitude - startLat
            val deltaLon = targetGeo.longitude - startLon

            // Če gre za majhen premik (hoja), naredi nekaj interpolacijskih korakov za popolnoma gladko drsenje
            if (kotlin.math.abs(deltaLat) < 0.0012 && kotlin.math.abs(deltaLon) < 0.0012 && (deltaLat != 0.0 || deltaLon != 0.0)) {
                val steps = 6
                for (step in 1..steps) {
                    val progress = step.toFloat() / steps
                    marker.position = GeoPoint(
                        startLat + deltaLat * progress,
                        startLon + deltaLon * progress
                    )
                    mapView.postInvalidate()
                    kotlinx.coroutines.delay(35)
                }
            } else {
                marker.position = targetGeo
                mapView.postInvalidate()
            }
        }
    }

    // Posodobitev 20 zelenih pikic (lokalov)
    LaunchedEffect(lokali, selectedLokal) {
        // Počisti stare oznake lokalov
        pubMarkersRef.forEach { mapView.overlays.remove(it) }
        pubMarkersRef.clear()

        lokali.forEach { lokal ->
            val isSelected = selectedLokal?.name == lokal.name && selectedLokal?.address == lokal.address
            createMarkerSafe(mapView)?.let { marker ->
                marker.position = GeoPoint(lokal.lat, lokal.lon)
                marker.icon = MapMarkerUtils.createPubMarkerDrawable(context, isSelected = isSelected)
                marker.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                marker.title = lokal.name
                marker.setInfoWindow(null)
                marker.setOnMarkerClickListener { _, _ ->
                    mapNavViewModel.setSelectedLokal(lokal)
                    mapView.controller.animateTo(marker.position)
                    true
                }
                mapView.overlays.add(marker)
                pubMarkersRef.add(marker)
            }
        }
        // Ohrani uporabnikovo modro pikico na samem vrhu slojev
        userMarkerRef?.let { userMarker ->
            mapView.overlays.remove(userMarker)
            mapView.overlays.add(userMarker)
        }
        mapView.postInvalidate()
    }

    // Posodobitev radarja prijateljev iz Pivske Klape na zemljevidu
    LaunchedEffect(squadMembers) {
        squadMarkersRef.forEach { mapView.overlays.remove(it) }
        squadMarkersRef.clear()

        squadMembers.forEach { member ->
            val lat = member.lat
            val lon = member.lon
            // Ne izrisuj samega sebe (za uporabnika imamo že modro piko)
            if (lat != null && lon != null && member.id != squadViewModel.myUserId) {
                createMarkerSafe(mapView)?.let { marker ->
                    marker.position = GeoPoint(lat, lon)
                    marker.icon = MapMarkerUtils.createSquadFriendMarkerDrawable(context, member.name, 0)
                    marker.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                    marker.title = member.name
                    marker.setInfoWindow(null)
                    marker.setOnMarkerClickListener { _, _ ->
                        navController.navigate(Routes.SQUAD)
                        true
                    }
                    mapView.overlays.add(marker)
                    squadMarkersRef.add(marker)
                }
            }
        }
        userMarkerRef?.let { userMarker ->
            mapView.overlays.remove(userMarker)
            mapView.overlays.add(userMarker)
        }
        mapView.postInvalidate()
    }

    // Posodobitev izrisa pešpoti (Polyline z belim robom in krepko zeleno linijo, ki se natanko ujema s puščico)
    LaunchedEffect(routePoints) {
        routeCasingPolylineRef?.let { mapView.overlays.remove(it) }
        routePolylineRef?.let { mapView.overlays.remove(it) }
        routeCasingPolylineRef = null
        routePolylineRef = null

        if (routePoints.isNotEmpty()) {
            // 1. Spodnji beli rob (casing), ki se natanko ujema z belim robom navigacijske puščice
            val casing = Polyline().apply {
                setPoints(routePoints)
                outlinePaint.color = AndroidColor.WHITE
                outlinePaint.strokeWidth = 24f
                outlinePaint.strokeCap = android.graphics.Paint.Cap.ROUND
                outlinePaint.strokeJoin = android.graphics.Paint.Join.ROUND
            }
            // 2. Glavna krepka navigacijska linija (#0F9D58, natanko enaka barvi glave puščice)
            val polyline = Polyline().apply {
                setPoints(routePoints)
                outlinePaint.color = AndroidColor.parseColor("#0F9D58")
                outlinePaint.strokeWidth = 16f
                outlinePaint.strokeCap = android.graphics.Paint.Cap.ROUND
                outlinePaint.strokeJoin = android.graphics.Paint.Join.ROUND
            }

            mapView.overlays.add(0, casing) // Dno pod oznakami
            mapView.overlays.add(1, polyline)
            routeCasingPolylineRef = casing
            routePolylineRef = polyline

            // Samodejno centriraj pogled na celotno pot le pred začetkom navigacije (predogled)
            if (!isNavigating && routePoints.size >= 2) {
                mapView.zoomToBoundingBox(polyline.bounds, true, 120)
            }
        }
        mapView.postInvalidate()
    }

    // Posodobitev usmerjevalne navigacijske puščice na ovinku
    val currentStepIndex by mapNavViewModel.currentStepIndex.collectAsState()
    LaunchedEffect(isNavigating, currentStepIndex, routePoints) {
        if (!isNavigating) {
            maneuverMarkerRef?.let { mapView.overlays.remove(it) }
            maneuverMarkerRef = null
            mapView.postInvalidate()
            return@LaunchedEffect
        }

        val step = mapNavViewModel.getCurrentStep()
        val loc = step?.maneuver?.location
        if (loc != null && loc.size >= 2) {
            val geo = GeoPoint(loc[1], loc[0])
            val marker = maneuverMarkerRef ?: createMarkerSafe(mapView)?.also {
                it.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                it.setInfoWindow(null)
                it.setFlat(true) // Glodano na cestišče: puščica se NE vrti z zaslonom, ampak leži na cesti
                mapView.overlays.add(it)
                maneuverMarkerRef = it
            }
            marker?.let {
                it.setFlat(true)
                it.position = geo

                // Poišči segment poti pred in za ovinkom za natančno poravnavo puščice s cesto
                var bestIdx = -1
                var minDist = Double.MAX_VALUE
                for (i in routePoints.indices) {
                    val d = routePoints[i].distanceToAsDouble(geo)
                    if (d < minDist) {
                        minDist = d
                        bestIdx = i
                    }
                }

                val bIn: Float
                val bOut: Float
                if (bestIdx != -1 && routePoints.size >= 2) {
                    val pBefore = if (bestIdx > 0) routePoints[bestIdx - 1] else routePoints[0]
                    val pAfter = if (bestIdx < routePoints.size - 1) routePoints[bestIdx + 1] else routePoints.last()
                    val rawIn = calculateSegmentBearing(pBefore, geo)
                    val rawOut = calculateSegmentBearing(geo, pAfter)
                    bIn = if (pBefore != geo) rawIn else step.maneuver.bearingBefore.toFloat()
                    bOut = if (geo != pAfter) rawOut else step.maneuver.bearingAfter.toFloat()
                } else {
                    bIn = step.maneuver.bearingBefore.toFloat()
                    bOut = step.maneuver.bearingAfter.toFloat()
                }

                val rawTurn = ((bOut - bIn + 540f) % 360f) - 180f

                it.icon = MapMarkerUtils.createDynamicTurnArrowDrawable(
                    context = context,
                    turnAngleDeg = rawTurn
                )
                it.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                it.rotation = -bIn
                it.title = MapMarkerUtils.translateManeuver(step.maneuver.type, step.maneuver.modifier, step.name)
            }
            // Zagotovi, da je uporabnikova modra pikica na samem vrhu
            userMarkerRef?.let { userMarker ->
                mapView.overlays.remove(userMarker)
                mapView.overlays.add(userMarker)
            }
            mapView.postInvalidate()
        } else {
            maneuverMarkerRef?.let { mapView.overlays.remove(it) }
            maneuverMarkerRef = null
            mapView.postInvalidate()
        }
    }

    // Poslušaj ukaz za prekinitev navigacije iz potisnega obvestila
    LaunchedEffect(Unit) {
        com.example.sankfinder.notifications.NavigationBridge.stopNavigationFlow.collect {
            mapNavViewModel.stopNavigation()
        }
    }

    // Sproti posodabljaj interaktivno potisno obvestilo med navigacijo (slika 3)
    LaunchedEffect(isNavigating, distanceToNextStep, remainingDistance, currentStepIndex) {
        if (isNavigating) {
            val step = mapNavViewModel.getCurrentStep()
            val stepText = MapMarkerUtils.translateManeuver(
                step?.maneuver?.type,
                step?.maneuver?.modifier,
                step?.name
            )
            val destName = selectedLokal?.name ?: "Izbrani šank"
            val totalDist = mapNavViewModel.activeRoute.value?.distance ?: remainingDistance

            com.example.sankfinder.notifications.SankNotificationHelper.showLiveNavigationNotification(
                context = context,
                maneuverText = stepText,
                distanceToNext = distanceToNextStep,
                remainingMeters = remainingDistance,
                remainingSeconds = remainingDuration,
                destLokalName = destName,
                totalDistance = totalDist,
                modifier = step?.maneuver?.modifier,
                type = step?.maneuver?.type
            )
        } else {
            com.example.sankfinder.notifications.SankNotificationHelper.dismissNavigationNotification(context)
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            com.example.sankfinder.notifications.SankNotificationHelper.dismissNavigationNotification(context)
        }
    }

    Scaffold(
        bottomBar = {
            if (!isNavigating) {
                BottomNavBar(navController = navController)
            }
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // 1. ZEMLJEVID ČEZ CEL ZASLON
            AndroidView(
                factory = { mapView },
                modifier = Modifier.fillMaxSize()
            )

            // 2. ZGORNJA VRSTICA: GLAVNE KONTROLE (Če navigacija NI aktivna)
            if (!isNavigating) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                        .align(Alignment.TopCenter),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (activeSquadRoom != null) {
                        Surface(
                            shape = RoundedCornerShape(20.dp),
                            color = BeerGold,
                            shadowElevation = 6.dp,
                            modifier = Modifier.clickable { navController.navigate(Routes.SQUAD) }
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Groups,
                                    contentDescription = null,
                                    tint = Color.Black,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "Klapa: ${activeSquadRoom!!.code} (${squadMembers.size})",
                                    color = Color.Black,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp
                                )
                            }
                        }
                    } else {
                        Spacer(modifier = Modifier.width(1.dp))
                    }

                    // Gumba: Osveži šanke in Centriraj lokacijo
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FloatingActionButton(
                            onClick = {
                                userLocation?.let { loc ->
                                    lokalViewModel.fetchLokali(loc.latitude, loc.longitude, radius = savedRadius, limit = savedLimit)
                                } ?: run {
                                    coroutineScope.launch {
                                        snackbarHostState.showSnackbar("Čakam na GPS signal...")
                                    }
                                }
                            },
                            modifier = Modifier.size(44.dp),
                            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f),
                            contentColor = MaterialTheme.colorScheme.primary
                        ) {
                            Icon(Icons.Default.Refresh, contentDescription = "Osveži", modifier = Modifier.size(20.dp))
                        }

                        FloatingActionButton(
                            onClick = {
                                userLocation?.let { loc ->
                                    isTrackingUser = true
                                    mapView.controller.animateTo(GeoPoint(loc.latitude, loc.longitude))
                                    mapView.controller.setZoom(17.0)
                                } ?: run {
                                    coroutineScope.launch {
                                        snackbarHostState.showSnackbar("Pridobivam lokacijo...")
                                    }
                                }
                            },
                            modifier = Modifier.size(44.dp),
                            containerColor = if (isTrackingUser) BeerGold else MaterialTheme.colorScheme.primary,
                            contentColor = if (isTrackingUser) Color.Black else MaterialTheme.colorScheme.onPrimary
                        ) {
                            Icon(Icons.Default.MyLocation, contentDescription = "Moja lokacija", modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }

            // 3. AKTIVNI TURN-BY-TURN NAVIGACIJSKI HUD (Google Maps slog)
            AnimatedVisibility(
                visible = isNavigating,
                enter = slideInVertically { -it } + fadeIn(),
                exit = slideOutVertically { -it } + fadeOut(),
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopCenter)
            ) {
                NavigationTurnHud(
                    mapNavViewModel = mapNavViewModel,
                    distanceToNext = distanceToNextStep,
                    onStopNavigation = { mapNavViewModel.stopNavigation() }
                )
            }

            // 4. SPODNJA KARTICA LOKALA (Google Maps Bottom Sheet ob kliku na zeleno pikico)
            AnimatedVisibility(
                visible = selectedLokal != null && !isNavigating,
                enter = slideInVertically { it } + fadeIn(),
                exit = slideOutVertically { it } + fadeOut(),
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .padding(16.dp)
            ) {
                selectedLokal?.let { lokal ->
                    LokalDetailsBottomCard(
                        lokal = lokal,
                        userLocation = userLocation,
                        isLoadingRoute = isLoadingRoute,
                        onClose = { mapNavViewModel.setSelectedLokal(null) },
                        onStartWalk = { mapNavViewModel.startNavigation(lokal) },
                        onLogVisit = {
                            historyViewModel.addSimpleVisit(context, lokal)
                            coroutineScope.launch {
                                snackbarHostState.showSnackbar("Obisk v '${lokal.name}' zabeležen!")
                            }
                        },
                        onScanReceipt = { lokalForReceiptScan = lokal },
                        onOpenExternalMaps = { openInExternalMaps(context, lokal) }
                    )
                }
            }

            // GUMB ZA PONOVNO CENTRIRANJE IN USMERITEV V SMER HOJE (Google Maps slog)
            AnimatedVisibility(
                visible = isNavigating && !isTrackingUser,
                enter = scaleIn() + fadeIn(),
                exit = scaleOut() + fadeOut(),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 96.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(24.dp),
                    color = BeerGold,
                    shadowElevation = 8.dp,
                    modifier = Modifier.clickable {
                        isTrackingUser = true
                        val loc = userLocation
                        if (loc != null) {
                            val targetGeo = GeoPoint(loc.latitude, loc.longitude)
                            mapView.controller.setZoom(18.5)
                            mapView.controller.animateTo(targetGeo)
                            val walkingBearing = mapNavViewModel.getRouteWalkingBearing()
                            if (walkingBearing != null) {
                                val newOrientation = (360f - (walkingBearing % 360f)) % 360f
                                mapView.mapOrientation = newOrientation
                                mapOrientationDeg = newOrientation
                                mapView.postInvalidate()
                            }
                        }
                    }
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 9.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Navigation,
                            contentDescription = "Centriraj",
                            tint = Color.Black,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Centriraj",
                            color = Color.Black,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                    }
                }
            }

            // 5. SPODNJI STATUS MED NAVIGACIJO (Čas hoje, metri in zaključek)
            AnimatedVisibility(
                visible = isNavigating,
                enter = slideInVertically { it } + fadeIn(),
                exit = slideOutVertically { it } + fadeOut(),
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .padding(16.dp)
            ) {
                NavigationStatusBar(
                    targetLokal = selectedLokal,
                    remainingMeters = remainingDistance,
                    remainingSeconds = remainingDuration,
                    onEndNavigation = { mapNavViewModel.stopNavigation() }
                )
            }

            // 6. ČESTITKA OB PRIHODU NA ŠANK
            if (hasArrived) {
                ArrivalCelebrationDialog(
                    lokal = selectedLokal,
                    onDismiss = {
                        mapNavViewModel.stopNavigation()
                        mapNavViewModel.setSelectedLokal(null)
                    }
                )
            }

            // 7. DESNI PLAVAJOČI KONTROLNI STOLPEC (Kompas, Povečava +, Pomanjšava -)
            Column(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // KOMPAS GUMB (Pojavi se samodejno, če je zemljevid zasukan, in kaže smer severa)
                AnimatedVisibility(
                    visible = kotlin.math.abs(mapOrientationDeg) >= 1.5f,
                    enter = fadeIn(),
                    exit = fadeOut()
                ) {
                    Card(
                        shape = CircleShape,
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f)
                        ),
                        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
                        modifier = Modifier
                            .size(42.dp)
                            .clickable {
                                mapView.mapOrientation = 0f
                                mapOrientationDeg = 0f
                                mapView.postInvalidate()
                            }
                    ) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Navigation,
                                contentDescription = "Ponastavi sever",
                                tint = BeerGold,
                                modifier = Modifier
                                    .size(24.dp)
                                    .rotate(-mapOrientationDeg)
                            )
                        }
                    }
                }

                // GUMBA ZA ZOOM: + in - (Kompaktna, elegantna na strani, ki zamenjata prejšnje prevelike bele)
                Card(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f)
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 5.dp)
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(2.dp)
                    ) {
                        IconButton(
                            onClick = {
                                mapView.controller.zoomIn()
                            },
                            modifier = Modifier.size(36.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = "Povečaj",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp)
                            )
                        }

                        HorizontalDivider(
                            modifier = Modifier.width(24.dp),
                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
                            thickness = 0.5.dp
                        )

                        IconButton(
                            onClick = {
                                mapView.controller.zoomOut()
                            },
                            modifier = Modifier.size(36.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Remove,
                                contentDescription = "Pomanjšaj",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }
        }
    }

    // Modalni skener računa
    if (lokalForReceiptScan != null) {
        ReceiptScannerDialog(
            initialLokal = lokalForReceiptScan,
            onReceiptScanned = { visit ->
                historyViewModel.addOrUpdateVisit(context, visit)
                val pub = visit.lokal.name
                lokalForReceiptScan = null
                coroutineScope.launch {
                    snackbarHostState.showSnackbar("Račun za '$pub' uspešno poskeniran!")
                }
            },
            onDismiss = { lokalForReceiptScan = null }
        )
    }
}

/**
 * Zgornji zeleni navigacijski HUD v slogu Google Maps
 */
@Composable
fun NavigationTurnHud(
    mapNavViewModel: MapNavigationViewModel,
    distanceToNext: Double,
    onStopNavigation: () -> Unit
) {
    val step = mapNavViewModel.getCurrentStep()
    val maneuverText = MapMarkerUtils.translateManeuver(
        step?.maneuver?.type,
        step?.maneuver?.modifier,
        step?.name
    )

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
            .shadow(10.dp, RoundedCornerShape(16.dp)),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1B5E20)), // Temno zelena Google Maps
        shape = RoundedCornerShape(16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Smerna ikona
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(Color.White.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = when (step?.maneuver?.modifier?.lowercase()) {
                        "left" -> Icons.Default.TurnLeft
                        "right" -> Icons.Default.TurnRight
                        "sharp left" -> Icons.Default.TurnSharpLeft
                        "sharp right" -> Icons.Default.TurnSharpRight
                        "slight left" -> Icons.Default.TurnSlightLeft
                        "slight right" -> Icons.Default.TurnSlightRight
                        else -> Icons.AutoMirrored.Filled.DirectionsWalk
                    },
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(30.dp)
                )
            }

            Spacer(modifier = Modifier.width(14.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = MapMarkerUtils.formatDistance(distanceToNext),
                    style = MaterialTheme.typography.titleLarge.copy(
                        fontWeight = FontWeight.Black,
                        color = Color.White
                    )
                )
                Text(
                    text = maneuverText,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.9f)
                    ),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            IconButton(onClick = onStopNavigation) {
                Icon(Icons.Default.Close, contentDescription = "Prekliči", tint = Color.White)
            }
        }
    }
}

/**
 * Spodnja statusna vrstica med navigacijo (preostala razdalja in čas)
 */
@Composable
fun NavigationStatusBar(
    targetLokal: Lokal?,
    remainingMeters: Double,
    remainingSeconds: Double,
    onEndNavigation: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(12.dp, RoundedCornerShape(20.dp)),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = MapMarkerUtils.formatDuration(remainingSeconds),
                        style = MaterialTheme.typography.titleLarge.copy(
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF2E7D32)
                        )
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "• ${MapMarkerUtils.formatDistance(remainingMeters)}",
                        style = MaterialTheme.typography.titleMedium.copy(
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "• ${MapMarkerUtils.formatEta(remainingSeconds)}",
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    )
                }
                targetLokal?.let {
                    Text(
                        text = "Cilj: ${it.name}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            Button(
                onClick = onEndNavigation,
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("Končaj", fontWeight = FontWeight.Bold)
            }
        }
    }
}

/**
 * Google Maps slog kartice lokala s podrobnostmi ob kliku na zeleno pikico
 */
@Composable
fun LokalDetailsBottomCard(
    lokal: Lokal,
    userLocation: Location?,
    isLoadingRoute: Boolean,
    onClose: () -> Unit,
    onStartWalk: () -> Unit,
    onLogVisit: () -> Unit,
    onScanReceipt: () -> Unit,
    onOpenExternalMaps: () -> Unit
) {
    val distanceMeters = remember(lokal, userLocation) {
        if (userLocation != null) {
            val pubLoc = Location("pub").apply {
                latitude = lokal.lat
                longitude = lokal.lon
            }
            userLocation.distanceTo(pubLoc).toDouble()
        } else null
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(16.dp, RoundedCornerShape(24.dp)),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(24.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
        ) {
            // Glava: Ime in gumb Zapri
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = lokal.name,
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = lokal.address,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                IconButton(onClick = onClose, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Default.Close, contentDescription = "Zapri", tint = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Razdalja in predviden čas hoje
            distanceMeters?.let { meters ->
                val walkMins = (meters / 80).toInt().coerceAtLeast(1) // ~80m na minuto
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .background(
                            Color(0xFF2E7D32).copy(alpha = 0.12f),
                            RoundedCornerShape(8.dp)
                        )
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.DirectionsWalk,
                        contentDescription = null,
                        tint = Color(0xFF2E7D32),
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "${MapMarkerUtils.formatDistance(meters)} • ~$walkMins min hoje",
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF2E7D32)
                        )
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // Delovni čas / telefon če obstaja
            if (lokal.openingHours != null || lokal.phone != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    lokal.openingHours?.let { hours ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.AccessTime, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(hours, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                        }
                    }
                    lokal.phone?.let { phone ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(phone, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            // GLAVNI GUMB ZA NAVIGACIJO (V ŽIVO PEŠ)
            Button(
                onClick = onStartWalk,
                enabled = !isLoadingRoute,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF2E7D32),
                    contentColor = Color.White
                )
            ) {
                if (isLoadingRoute) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Računam pešpot...")
                } else {
                    Icon(
                        imageVector = Icons.Default.Navigation,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "NAVIGIRAJ (PEŠ)",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // DODATNA DEJANJA: Označi, Skeniraj račun, Google Maps
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = onLogVisit,
                    modifier = Modifier.weight(1f).height(38.dp),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.BookmarkAdded, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Označi", style = MaterialTheme.typography.labelSmall)
                }

                OutlinedButton(
                    onClick = onScanReceipt,
                    modifier = Modifier.weight(1f).height(38.dp),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.QrCodeScanner, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Račun", style = MaterialTheme.typography.labelSmall)
                }

                OutlinedButton(
                    onClick = onOpenExternalMaps,
                    modifier = Modifier.weight(1f).height(38.dp),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("G-Maps", style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

/**
 * Dialog ob prihodu na šank
 */
@Composable
fun ArrivalCelebrationDialog(
    lokal: Lokal?,
    onDismiss: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp)
            .shadow(20.dp, RoundedCornerShape(24.dp)),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Default.SportsBar,
                contentDescription = null,
                tint = Color(0xFFFFB703),
                modifier = Modifier.size(64.dp)
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "Prispeli ste na šank!",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = lokal?.name ?: "Vaš izbrani šank",
                style = MaterialTheme.typography.titleMedium.copy(color = MaterialTheme.colorScheme.primary),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "Čas je za zasluženo hladno pijačo! Na zdravje!",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(20.dp))
            Button(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth().height(46.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFFB703))
            ) {
                Text("Čin čin!", color = Color.Black, fontWeight = FontWeight.Bold)
            }
        }
    }
}

fun openInExternalMaps(context: Context, lokal: Lokal) {
    val lat = lokal.lat
    val lon = lokal.lon
    val uri = Uri.parse("google.navigation:q=$lat,$lon&mode=w")
    val intent = Intent(Intent.ACTION_VIEW, uri)
    if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try {
        context.startActivity(intent)
    } catch (_: Exception) {
        val browserUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=walking")
        context.startActivity(Intent(Intent.ACTION_VIEW, browserUri))
    }
}

/**
 * Izračuna azimut (bearing v stopinjah 0..360) med dvema točkama na sferi
 */
private fun calculateSegmentBearing(p1: GeoPoint, p2: GeoPoint): Float {
    val lat1 = Math.toRadians(p1.latitude)
    val lon1 = Math.toRadians(p1.longitude)
    val lat2 = Math.toRadians(p2.latitude)
    val lon2 = Math.toRadians(p2.longitude)
    val dLon = lon2 - lon1
    val y = Math.sin(dLon) * Math.cos(lat2)
    val x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon)
    val brng = Math.toDegrees(Math.atan2(y, x)).toFloat()
    return (brng + 360f) % 360f
}


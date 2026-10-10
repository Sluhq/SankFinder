package com.example.sankfinder.location

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices

class LocationManager(private val activity: Activity) {

    companion object {
        const val LOCATION_PERMISSION_REQUEST = 1001
    }

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(activity)

    fun zahtevajDovoljenjeLokacije() {
        val fineGranted = ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseGranted = ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (!fineGranted && !coarseGranted) {

            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ),
                LOCATION_PERMISSION_REQUEST
            )
        } else if (!fineGranted && coarseGranted) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                LOCATION_PERMISSION_REQUEST
            )
        }
    }

    fun imaDovoljenje(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun pridobiLokacijo(onLokacija: (latitude: Double, longitude: Double) -> Unit) {
        val fineGranted = ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (fineGranted) {
            fusedLocationClient.lastLocation.addOnSuccessListener { location ->
                location?.let { onLokacija(it.latitude, it.longitude) }
            }
        }
    }

    private var activeLocationCallback: com.google.android.gms.location.LocationCallback? = null

    @android.annotation.SuppressLint("MissingPermission")
    fun zacniSledenjeLokacije(
        intervalMs: Long = 1000L,
        onNovaLokacija: (android.location.Location) -> Unit
    ) {
        if (!imaDovoljenje()) return

        ustaviSledenjeLokacije()

        val locationRequest = com.google.android.gms.location.LocationRequest.Builder(
            com.google.android.gms.location.Priority.PRIORITY_HIGH_ACCURACY,
            intervalMs
        ).setMinUpdateIntervalMillis(500L)
         .setMinUpdateDistanceMeters(0.5f)
         .build()

        val callback = object : com.google.android.gms.location.LocationCallback() {
            override fun onLocationResult(result: com.google.android.gms.location.LocationResult) {
                result.lastLocation?.let { onNovaLokacija(it) }
            }
        }

        activeLocationCallback = callback
        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            callback,
            android.os.Looper.getMainLooper()
        )
    }

    fun ustaviSledenjeLokacije() {
        activeLocationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
            activeLocationCallback = null
        }
    }
}

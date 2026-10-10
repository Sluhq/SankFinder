package com.example.sankfinder.data

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class OsrmRouteResponse(
    @Json(name = "code") val code: String,
    @Json(name = "routes") val routes: List<OsrmRoute> = emptyList()
)

@JsonClass(generateAdapter = true)
data class OsrmRoute(
    @Json(name = "distance") val distance: Double = 0.0,
    @Json(name = "duration") val duration: Double = 0.0,
    @Json(name = "geometry") val geometry: OsrmGeometry? = null,
    @Json(name = "legs") val legs: List<OsrmLeg> = emptyList()
)

@JsonClass(generateAdapter = true)
data class OsrmGeometry(
    @Json(name = "coordinates") val coordinates: List<List<Double>> = emptyList(),
    @Json(name = "type") val type: String = "LineString"
)

@JsonClass(generateAdapter = true)
data class OsrmLeg(
    @Json(name = "distance") val distance: Double = 0.0,
    @Json(name = "duration") val duration: Double = 0.0,
    @Json(name = "summary") val summary: String? = null,
    @Json(name = "steps") val steps: List<OsrmStep> = emptyList()
)

@JsonClass(generateAdapter = true)
data class OsrmStep(
    @Json(name = "distance") val distance: Double = 0.0,
    @Json(name = "duration") val duration: Double = 0.0,
    @Json(name = "name") val name: String? = null,
    @Json(name = "mode") val mode: String? = null,
    @Json(name = "maneuver") val maneuver: OsrmManeuver? = null
)

@JsonClass(generateAdapter = true)
data class OsrmManeuver(
    @Json(name = "location") val location: List<Double> = emptyList(),
    @Json(name = "type") val type: String = "turn",
    @Json(name = "modifier") val modifier: String? = null,
    @Json(name = "bearing_after") val bearingAfter: Int = 0,
    @Json(name = "bearing_before") val bearingBefore: Int = 0
)

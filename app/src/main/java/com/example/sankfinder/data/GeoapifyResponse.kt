package com.example.sankfinder.data

data class GeoapifyResponse(
    val features: List<Feature>
)
data class Feature(
    val properties: Properties,
    val geometry: Geometry
)
data class Properties(
    val name: String?,
    val formatted: String?,
    val website: String?,
    val opening_hours: String?,
    val contact: Contact?,
    val catering: Catering?
)
data class Contact(
    val phone: String?
)
data class Catering(
    val cuisine: String?,
    val diet: Diet?
)
data class Diet(
    val vegetarian: Boolean?
)
data class Geometry(
    val coordinates: List<Double>
)

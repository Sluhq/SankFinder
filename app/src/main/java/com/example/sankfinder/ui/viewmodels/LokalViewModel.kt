package com.example.sankfinder.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.sankfinder.data.Lokal
import com.example.sankfinder.network.GeoapifyApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class LokalViewModel : ViewModel() {

    private val _lokali = MutableStateFlow<List<Lokal>>(emptyList())
    val lokali: StateFlow<List<Lokal>> = _lokali

    private val _warningMessage = MutableStateFlow<String?>(null)
    val warningMessage: StateFlow<String?> = _warningMessage

    fun dismissWarning() {
        _warningMessage.value = null
    }

    fun clearLokali() {
        _lokali.value = emptyList()
    }

    // Zanesljivi prednaloženi lokali v Ljubljani, če ni internetne povezave
    private val fallbackLokali = listOf(
        Lokal("Krakovc", "Krakovski nasip 12, 1000 Ljubljana", 46.0468, 14.5042, "Coffee_shop, Bar", "+386 64 139 034", null, "Mo-Su 08:00-22:00"),
        Lokal("Nostalgija Vintage Cafe", "Krakovski nasip 8, 1000 Ljubljana", 46.0461, 14.5045, "Bar, Cafe", "+386 1 425 01 22", null, "Mo-Su 08:00-01:00"),
        Lokal("Pri Škofu", "Rečna ulica 8, 1000 Ljubljana", 46.0452, 14.5036, "Gostilna, Bar", "+386 1 426 45 08", null, "We-Sa 18:00-23:00; Su 12:00-16:00"),
        Lokal("Pivnica Lajbah", "Grudnovo nabrežje 15, 1000 Ljubljana", 46.0438, 14.5074, "Pivnica, Craft beer", "+386 1 283 23 88", "https://lajbah.com", "Mo-Sa 11:00-24:00"),
        Lokal("Sir William's Pub", "Tavčarjeva ulica 8a, 1000 Ljubljana", 46.0537, 14.5076, "Pub, Beer bar", "+386 1 231 03 40", "https://sirwilliams.si", "Mo-Sa 08:00-01:00"),
        Lokal("Cutty Sark Pub", "Knafljev prehod 1, 1000 Ljubljana", 46.0514, 14.5043, "Pub", "+386 1 425 21 83", null, "Mo-Su 08:00-01:00"),
        Lokal("Sax Pub", "Eipprova ulica 7, 1000 Ljubljana", 46.0435, 14.5029, "Jazz Pub", "+386 1 425 01 54", null, "Mo-Su 09:00-01:00"),
        Lokal("Pritličje", "Mestni trg 25, 1000 Ljubljana", 46.0498, 14.5072, "Bar, Club", "+386 1 425 04 44", null, "Mo-Su 09:00-01:00"),
        Lokal("Daktari", "Krekov trg 7, 1000 Ljubljana", 46.0515, 14.5103, "Cafe, Bar", "+386 1 433 01 80", null, "Mo-Su 08:00-01:00"),
        Lokal("BiKoFe", "Židovska steza 2, 1000 Ljubljana", 46.0496, 14.5048, "Bar", "+386 1 251 12 00", null, "Mo-Su 08:00-00:00"),
        // Šiška & Bežigrad
        Lokal("Gostilna Maratonec", "Podmilščakova ulica 24, 1000 Ljubljana", 46.0712, 14.5048, "Gostilna, Bar", "+386 1 436 43 28", null, "Mo-Fr 08:00-22:00"),
        Lokal("Bar trikotnik", "Podmilščakova ulica 46, 1000 Ljubljana", 46.0754, 14.5019, "Bar, Kava", null, null, "Mo-Sa 07:00-23:00"),
        Lokal("Pivnica Union", "Celovška cesta 22, 1000 Ljubljana", 46.0597, 14.4983, "Pivnica, Bar", "+386 1 475 70 00", "https://pivnica-union.si", "Mo-Sa 11:00-24:00"),
        Lokal("Kavarna Tiskarna", "Dunajska cesta 123, 1000 Ljubljana", 46.0772, 14.5126, "Bar, Cafe, Burger", "+386 40 435 554", null, "Mo-Fr 07:30-23:00, Sa 09:00-23:00"),
        Lokal("Lepotica in Zver Bar", "Drenikova ulica 18, 1000 Ljubljana", 46.0701, 14.4965, "Bar, Pub", "+386 41 332 211", null, "Mo-Su 08:00-24:00")
    )

    private var _preferredLimit: Int = 20
    val preferredLimit: Int get() = _preferredLimit

    private var lastLat: Double? = null
    private var lastLon: Double? = null
    private var lastRadius: Int = 2000

    fun setPreferredLimit(limit: Int, forceRefresh: Boolean = true) {
        val coerced = limit.coerceIn(5, 100)
        val changed = _preferredLimit != coerced
        _preferredLimit = coerced
        if (changed && forceRefresh && lastLat != null && lastLon != null) {
            fetchLokali(lastLat!!, lastLon!!, lastRadius, coerced)
        }
    }

    // Legendarni nočni burek, pekarne & fast food kotički za "Burek pavzo"
    val legendaryBurekSpots = listOf(
        Lokal("Pekarna Legiša (Rimska)", "Rimska cesta 16, 1000 Ljubljana", 46.0468, 14.5015, "Pekarna, Burek, Pečivo", "+386 41 742 686", null, "Pon-Pet 06:00 - 19:00, Sob 07:00 - 13:00"),
        Lokal("Pekarna Dvojka", "Nazorjeva ulica 6, 1000 Ljubljana", 46.0526, 14.5042, "Pekarna, Sendviči, Burek", "+386 1 425 70 80", null, "Pon-Ned 06:00 - 03:00 (Nočni obrat)"),
        Lokal("Burek Trubarjeva", "Trubarjeva cesta 22, 1000 Ljubljana", 46.0518, 14.5095, "Burek, Balkanski žar", "+386 41 987 654", null, "Pon-Ned 09:00 - 03:00 (Nočni obrat)"),
        Lokal("Pekarna Noč in Dan", "Resljeva cesta 16, 1000 Ljubljana", 46.0535, 14.5109, "Pekarna, Burek, Prigrizki", "+386 40 123 456", null, "24/7 Non-stop"),
        Lokal("Burek Olimpija", "Slovenska cesta 58, 1000 Ljubljana", 46.0565, 14.5057, "Burek, Pekarna, Fast food", "+386 1 433 82 22", null, "24/7 Non-stop"),
        Lokal("Nobel Burek", "Miklošičeva cesta 30, 1000 Ljubljana", 46.0556, 14.5098, "Burek, Pizza, Fast food", "+386 1 430 40 40", null, "24/7 Non-stop"),
        Lokal("Fast Food Ajda Kolodvor", "Trg OF 13, 1000 Ljubljana", 46.0582, 14.5101, "Burgerji, Hot Dog, Fast food", "+386 1 430 20 10", null, "24/7 Non-stop"),
        Lokal("Pekarna Ajdovščina", "Trg Ajdovščina 1, 1000 Ljubljana", 46.0538, 14.5042, "Pekarna, Sendviči", "+386 1 234 56 78", null, "Pon-Sob 06:00 - 04:00 (Nočni obrat)"),
        Lokal("Pekarna Legiša (Dunajska)", "Dunajska cesta 49, 1000 Ljubljana", 46.0645, 14.5088, "Pekarna, Burek, Dnevno pecivo", "+386 41 742 686", null, "Pon-Pet 06:00 - 19:00, Sob 07:00 - 13:00"),
        Lokal("Dunajska Pekarna", "Dunajska cesta 87, 1000 Ljubljana", 46.0712, 14.5120, "Pekarna, Burek, Prigrizki", "+386 1 234 56 70", null, "Pon-Ned 06:00 - 22:00 (Vsak dan)"),
        Lokal("Domača pekarna Bežigrad", "Dunajska cesta 113, 1000 Ljubljana", 46.0745, 14.5126, "Pekarna, Kruh, Burek", "+386 1 430 90 90", null, "Pon-Pet 07:00 - 19:00, Ned 07:00 - 17:00"),
        Lokal("Burek Šiška", "Celovška cesta 111, 1000 Ljubljana", 46.0689, 14.4892, "Burek, Pekarna, Pite", "+386 1 515 22 11", null, "24/7 Non-stop")
    )

    fun fetchLokali(latitude: Double, longitude: Double, radius: Int = 2000, limit: Int = preferredLimit) {
        lastLat = latitude
        lastLon = longitude
        lastRadius = radius
        val queryLimit = limit.coerceIn(5, 100)
        viewModelScope.launch {
            try {
                val apiKey = "b2669a1530394868ae3a5abd6f38f7f2"
                val filter = "circle:$longitude,$latitude,$radius"
                val categories = "catering.bar,catering.pub,catering.restaurant"
                val bias = "proximity:$longitude,$latitude"
                val sort = "distance"

                val response = GeoapifyApi.retrofitService.getPlaces(
                    categories = categories,
                    filter = filter,
                    bias = bias,
                    sort = sort,
                    limit = queryLimit,
                    apiKey = apiKey
                )

                val lokaliList = response.features.mapNotNull { feature ->
                    val props = feature.properties
                    val coords = feature.geometry.coordinates
                    if (props != null && coords.size >= 2) {
                        Lokal(
                            name = props.name ?: "Neimenovan lokal",
                            address = props.formatted ?: "Ni naslova",
                            lat = coords[1],
                            lon = coords[0],
                            cuisine = props.catering?.cuisine,
                            phone = props.contact?.phone,
                            website = props.website,
                            openingHours = props.opening_hours
                        )
                    } else null
                }

                if (lokaliList.isNotEmpty()) {
                    _lokali.value = lokaliList
                    _warningMessage.value = null
                } else if (_lokali.value.isEmpty()) {
                    _lokali.value = fallbackLokali.take(queryLimit)
                }
            } catch (e: Exception) {
                // Če ni povezave, ohrani že naložene lokale ali naloži zanesljive lokalne
                if (_lokali.value.isEmpty()) {
                    _lokali.value = fallbackLokali.take(queryLimit)
                }
                _warningMessage.value = "Ni internetne povezave. Prikazani so shranjeni lokali."
            }
        }
    }
}

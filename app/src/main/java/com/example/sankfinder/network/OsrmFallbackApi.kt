package com.example.sankfinder.network

import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory

object OsrmFallbackApi {
    // Uradni javni OSRM foot strežnik za zanesljivo rezervno peš navigacijo
    private const val BASE_URL = "https://routing.openstreetmap.de/routed-foot/"

    private val moshi = Moshi.Builder()
        .add(KotlinJsonAdapterFactory())
        .build()

    val retrofitService: OsrmService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(NetworkClient.okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(OsrmService::class.java)
    }
}

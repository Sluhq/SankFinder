package com.example.sankfinder.network

import com.example.sankfinder.data.OsrmRouteResponse
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

interface OsrmService {
    @GET("route/v1/foot/{coordinates}")
    suspend fun getFootRoute(
        @Path(value = "coordinates", encoded = true) coordinates: String,
        @Query("overview") overview: String = "full",
        @Query("geometries") geometries: String = "geojson",
        @Query("steps") steps: Boolean = true
    ): OsrmRouteResponse
}

object OsrmApi {
    private const val BASE_URL = "https://sankfinder.sluga.me/"

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

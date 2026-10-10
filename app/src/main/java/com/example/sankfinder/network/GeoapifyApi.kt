package com.example.sankfinder.network

import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory

object GeoapifyApi {
    private const val BASE_URL = "https://api.geoapify.com/"

    private val moshi = Moshi.Builder()
        .add(KotlinJsonAdapterFactory())
        .build()

    val retrofitService: GeoapifyService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(NetworkClient.okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(GeoapifyService::class.java)
    }
}

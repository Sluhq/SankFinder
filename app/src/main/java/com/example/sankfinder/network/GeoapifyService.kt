package com.example.sankfinder.network

import com.example.sankfinder.data.GeoapifyResponse
import retrofit2.http.GET
import retrofit2.http.Query

interface GeoapifyService {
    @GET("v2/places")
    suspend fun getPlaces(
        @Query("categories") categories: String,
        @Query("filter") filter: String,
        @Query("bias") bias: String? = null,
        @Query("sort") sort: String? = null,
        @Query("limit") limit: Int,
        @Query("apiKey") apiKey: String
    ): GeoapifyResponse
}

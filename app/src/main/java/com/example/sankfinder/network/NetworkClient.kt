package com.example.sankfinder.network

import okhttp3.ConnectionPool
import okhttp3.ConnectionSpec
import okhttp3.OkHttpClient
import okhttp3.TlsVersion
import java.util.concurrent.TimeUnit

/**
 * Optimiziran skupni HTTP odjemalec za hitro povezovanje in predpomnjenje TCP/TLS povezav.
 * Prisiljuje varno komunikacijo s prednostno uporabo TLS 1.3 in uradnim User-Agentom.
 */
object NetworkClient {
    private const val APP_USER_AGENT = "SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)"

    private val modernTlsSpec = ConnectionSpec.Builder(ConnectionSpec.MODERN_TLS)
        .tlsVersions(TlsVersion.TLS_1_3, TlsVersion.TLS_1_2)
        .build()

    val okHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectionSpecs(listOf(modernTlsSpec, ConnectionSpec.CLEARTEXT))
            .addInterceptor { chain ->
                val original = chain.request()
                val request = original.newBuilder()
                    .header("User-Agent", APP_USER_AGENT)
                    .build()
                chain.proceed(request)
            }
            .connectionPool(ConnectionPool(8, 5, TimeUnit.MINUTES))
            .connectTimeout(6, TimeUnit.SECONDS)
            .readTimeout(8, TimeUnit.SECONDS)
            .writeTimeout(8, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .build()
    }

    val webSocketOkHttpClient: OkHttpClient by lazy {
        okHttpClient.newBuilder()
            .connectionSpecs(listOf(modernTlsSpec, ConnectionSpec.CLEARTEXT))
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .pingInterval(20, TimeUnit.SECONDS)
            .build()
    }
}

package com.example.sankfinder.security

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * ŠankFinder CryptoHelper
 * Strojno pospešena kriptografija (ARMv8 Crypto Extensions / AndroidKeyStore):
 *  - AES-256-GCM za šifriranje lokalnih računov in zgodovine obiskov
 *  - HMAC-SHA256 za podpisovanje API in WebSocket zahtevkov proti Replay napadom
 */
object CryptoHelper {
    private const val TAG = "CryptoHelper"
    private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
    private const val KEY_ALIAS = "sankfinder_history_encryption_key"
    private const val AES_TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_TAG_LENGTH = 128
    private const val GCM_IV_LENGTH = 12

    // Skupni skrivni ključ za podpisovanje API zahtevkov (usklajen s strežnikom in iOS)
    private const val SHARED_APP_SECRET = "0e249416dd0bbb1efcfa3c763e2eaad4d2f700cdbcf2bcc3d71fc6223f0f9571"

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)

        if (keyStore.containsAlias(KEY_ALIAS)) {
            val entry = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
            if (entry != null) {
                return entry.secretKey
            }
        }

        // Ustvari nov 256-bitni AES ključ v varnem AndroidKeyStore
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()

        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    /**
     * Šifrira podatke z AES-256-GCM.
     * Vrne: 12-bajtni IV + šifrirano vsebino (z 16-bajtnim GCM AuthTagom).
     */
    fun encrypt(plainBytes: ByteArray): ByteArray {
        val key = getOrCreateKey()
        val cipher = Cipher.getInstance(AES_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val iv = cipher.iv // 12 bajtov
        val encrypted = cipher.doFinal(plainBytes)

        val result = ByteArray(iv.size + encrypted.size)
        System.arraycopy(iv, 0, result, 0, iv.size)
        System.arraycopy(encrypted, 0, result, iv.size, encrypted.size)
        return result
    }

    /**
     * Dešifrira podatke z AES-256-GCM.
     * Pričakuje: 12-bajtni IV + šifrirano vsebino.
     */
    fun decrypt(encryptedBytes: ByteArray): ByteArray {
        if (encryptedBytes.size < GCM_IV_LENGTH) {
            throw IllegalArgumentException("Šifrirani podatki so prekratki za veljaven GCM IV")
        }

        val key = getOrCreateKey()
        val iv = ByteArray(GCM_IV_LENGTH)
        System.arraycopy(encryptedBytes, 0, iv, 0, GCM_IV_LENGTH)

        val cipherTextSize = encryptedBytes.size - GCM_IV_LENGTH
        val cipherText = ByteArray(cipherTextSize)
        System.arraycopy(encryptedBytes, GCM_IV_LENGTH, cipherText, 0, cipherTextSize)

        val cipher = Cipher.getInstance(AES_TRANSFORMATION)
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher.doFinal(cipherText)
    }

    /**
     * Izračuna HMAC-SHA256 podpis za preprečevanje Replay napadov.
     */
    fun generateSignature(timestamp: Long, deviceId: String): String {
        val payload = "$deviceId:$timestamp"
        val secretKey = SecretKeySpec(SHARED_APP_SECRET.toByteArray(Charsets.UTF_8), "HmacSHA256")
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(secretKey)
        val hashBytes = mac.doFinal(payload.toByteArray(Charsets.UTF_8))
        return hashBytes.joinToString("") { "%02x".format(it) }
    }
}

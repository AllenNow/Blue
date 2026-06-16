// KeystoreHelper.kt
// BlueSDK - Android Keystore 安全存储

package com.blue.sdk.internal

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec

object KeystoreHelper {

    private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
    private const val KEY_ALIAS_PREFIX = "com.blue.sdk."
    private const val GCM_IV_LENGTH = 12
    private const val GCM_TAG_LENGTH = 128

    private lateinit var context: Context

    fun init(context: Context) {
        this.context = context.applicationContext
    }

    fun save(key: String, value: ByteArray) {
        try {
            val encrypted = encrypt(value)
            val encoded = Base64.encodeToString(encrypted, Base64.DEFAULT)
            context.getSharedPreferences("BlueSDK", Context.MODE_PRIVATE)
                .edit()
                .putString(key, encoded)
                .apply()
        } catch (e: Exception) {
            BlueLogger.error("Keystore save failed: ${e.message}")
        }
    }

    fun loadBytes(key: String): ByteArray? {
        val encoded = context.getSharedPreferences("BlueSDK", Context.MODE_PRIVATE)
            .getString(key, null) ?: return null
        return try {
            decrypt(Base64.decode(encoded, Base64.DEFAULT))
        } catch (e: Exception) {
            BlueLogger.error("Keystore load failed: ${e.message}")
            null
        }
    }

    fun delete(key: String) {
        context.getSharedPreferences("BlueSDK", Context.MODE_PRIVATE)
            .edit()
            .remove(key)
            .apply()
    }

    private fun encrypt(data: ByteArray): ByteArray {
        val cipher = getCipher()
        val key = getOrCreateKey()
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val iv = cipher.iv
        val encrypted = cipher.doFinal(data)
        return iv + encrypted
    }

    private fun decrypt(data: ByteArray): ByteArray {
        val cipher = getCipher()
        val key = getOrCreateKey()
        val iv = data.copyOfRange(0, GCM_IV_LENGTH)
        val encrypted = data.copyOfRange(GCM_IV_LENGTH, data.size)
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher.doFinal(encrypted)
    }

    private fun getCipher(): Cipher {
        return Cipher.getInstance("${KeyProperties.KEY_ALGORITHM_AES}/${KeyProperties.BLOCK_MODE_GCM}/${KeyProperties.ENCRYPTION_PADDING_NONE}")
    }

    private fun getOrCreateKey(): javax.crypto.SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)

        val keyAlias = "$KEY_ALIAS_PREFIX.master"
        if (keyStore.containsAlias(keyAlias)) {
            return keyStore.getKey(keyAlias, null) as javax.crypto.SecretKey
        }

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        val spec = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }
}
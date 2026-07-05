package com.lianyu.ai.common

import android.content.Context
import org.json.JSONObject

/**
 * Open-source placeholder for the former private relay integration.
 *
 * The public build never contacts a bundled server and never returns embedded
 * credentials. Users must configure their own API keys in Settings.
 */
object RemoteKeyProvider {
    @Volatile
    var serverUrl: String = ""

    fun openSourceHandshake(ctx: Context): JSONObject = JSONObject().apply {
        put("ok", false)
        put("error", "open_source_build_requires_user_api_config")
    }

    fun getRandomModel(context: Context): String? = null
    fun clearCache(context: Context) = Unit

    /**
     * 开源 stub：公共构建不从服务器获取密钥，始终返回空列表。
     * 调用方（AiService）会将空列表视为"无可用密钥"并走用户自配密钥路径。
     */
    suspend fun fetchKeysAsync(context: Context, forceRefresh: Boolean = false): List<String> = emptyList()

    /**
     * 开源 stub：公共构建不持久化服务器握手结果，空实现。
     */
    fun storeHandshakeResult(context: Context, handshakeJson: JSONObject) = Unit
}

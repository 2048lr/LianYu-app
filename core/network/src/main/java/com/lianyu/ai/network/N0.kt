package com.lianyu.ai.network

import okhttp3.Interceptor
import okhttp3.Response

/**
 * Open-source compatibility stub for the former native request signer.
 *
 * 公开版本不附加内部安全头，所有请求直接放行。
 * 保留 Signer 构造参数仅为兼容测试调用，实际不执行签名。
 */
class N0(
    @Suppress("UNUSED_PARAMETER") signer: Signer = Signer { "" }
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response = chain.proceed(chain.request())

    /** 签名器接口（开源 stub，不执行实际签名） */
    fun interface Signer {
        fun sign(): String
    }
}

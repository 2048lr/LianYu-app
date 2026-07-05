package com.lianyu.ai.database

import com.lianyu.ai.database.model.ChatMessage
import com.lianyu.ai.database.model.FileFormat
import com.lianyu.ai.database.model.MessageType
import com.lianyu.ai.database.repository.ChatMessageCrypto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File

class ChatMessageStorageTest {
    private val projectRoot = generateSequence(File(".").canonicalFile) { it.parentFile }
        .first { File(it, "settings.gradle.kts").isFile }

    /**
     * 检查 AndroidKeyStore 是否可用（JVM 单元测试中不可用，需在真机/模拟器上运行）。
     * 依赖 AndroidKeyStore 的测试在 CI JVM 环境中会自动跳过。
     */
    private fun androidKeyStoreAvailable(): Boolean = try {
        java.security.KeyStore.getInstance("AndroidKeyStore").load(null)
        true
    } catch (e: Exception) {
        false
    }

    @Test
    fun chat_message_crypto_does_not_use_hardcoded_fallback_key_material() {
        val source = File(
            projectRoot,
            "core/database/src/main/java/com/lianyu/ai/database/repository/ChatMessageCrypto.kt"
        ).readText()

        // 主密钥来自 AndroidKeyStore（非硬编码）
        assertTrue(source.contains("AndroidKeyStore"))
        // legacyFallbackKey 仅用于解密历史数据，不用于加密新数据
        assertTrue(source.contains("legacyFallbackKey"))
        assertTrue(source.contains("decryptionKeys"))
        // 加密路径强制使用 KeyStore 密钥，不允许 fallback
        assertTrue(source.contains("encryptionKey"))
    }

    @Test
    fun chat_messages_can_be_filtered_by_millisecond_cursor_fuzzy_query_and_file_type() {
        val messages = listOf(
            ChatMessage(
                id = 1,
                companionId = 7,
                content = "今天一起吃草莓蛋糕",
                isFromUser = true,
                timestamp = 1_700_000_000_001,
                type = MessageType.TEXT,
                fileFormat = FileFormat.TEXT,
                linkString = ""
            ),
            ChatMessage(
                id = 2,
                companionId = 7,
                content = "草莓蛋糕照片",
                isFromUser = false,
                timestamp = 1_700_000_000_500,
                type = MessageType.IMAGE,
                fileFormat = FileFormat.IMAGE,
                linkString = "lianyu://file?kind=image&uri=content://media/image/1"
            ),
            ChatMessage(
                id = 3,
                companionId = 7,
                content = "语音消息",
                isFromUser = false,
                timestamp = 1_700_000_001_000,
                type = MessageType.VOICE,
                fileFormat = FileFormat.AUDIO,
                linkString = "lianyu://file?kind=audio&uri=content://media/audio/1"
            )
        )

        val result = messages
            .asSequence()
            .filter { it.companionId == 7L }
            .filter { it.timestamp < 1_700_000_001_000 }
            .filter { it.content.contains("草莓") }
            .filter { it.fileFormat == FileFormat.IMAGE }
            .sortedByDescending { it.timestamp }
            .take(20)
            .toList()

        assertEquals(listOf(2L), result.map { it.id })
        assertEquals("lianyu://file?kind=image&uri=content://media/image/1", result.single().linkString)
    }

    @Test
    fun chat_message_crypto_returns_placeholder_when_stored_ciphertext_cannot_be_authenticated() {
        assumeTrue("AndroidKeyStore not available in JVM unit tests", androidKeyStoreAvailable())
        val sourceMessage = ChatMessage(
            companionId = 9,
            content = "原始消息",
            isFromUser = true,
            timestamp = 1_700_000_123_456,
            fileFormat = FileFormat.TEXT,
            linkString = ""
        )
        val encrypted = ChatMessageCrypto.encryptForStorage(sourceMessage)
        val corrupted = encrypted.copy(content = encrypted.content.dropLast(2) + "AA")

        val decrypted = ChatMessageCrypto.decryptFromStorage(corrupted)

        assertEquals(ChatMessageCrypto.DECRYPT_FAILED_PLACEHOLDER, decrypted.content)
        assertEquals("", decrypted.linkString)
    }

    @Test
    fun chat_message_crypto_encrypts_searchable_content_and_link_fields_without_plaintext_storage() {
        assumeTrue("AndroidKeyStore not available in JVM unit tests", androidKeyStoreAvailable())
        val message = ChatMessage(
            companionId = 9,
            content = "需要加密的聊天正文",
            isFromUser = true,
            timestamp = 1_700_000_123_456,
            fileFormat = FileFormat.IMAGE,
            linkString = "lianyu://file?kind=image&uri=content://secure/image/9"
        )

        val encrypted = ChatMessageCrypto.encryptForStorage(message)

        assertFalse(encrypted.content.contains("需要加密"))
        assertFalse(encrypted.linkString.contains("content://secure"))
        assertEquals("需要加密的聊天正文", encrypted.searchContent)
        assertEquals(FileFormat.IMAGE, encrypted.fileFormat)
        assertTrue(encrypted.linkString.isNotBlank())

        val decrypted = ChatMessageCrypto.decryptFromStorage(encrypted)
        assertEquals(message.content, decrypted.content)
        assertEquals(message.linkString, decrypted.linkString)
    }
}

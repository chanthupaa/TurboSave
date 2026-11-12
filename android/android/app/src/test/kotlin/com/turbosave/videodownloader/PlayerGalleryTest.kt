package com.turbosave.videodownloader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class PlayerGalleryTest {
    @Test fun validatesOrderedImageItems() {
        val result = validateGalleryItems(listOf(
            mapOf("id" to 2, "uri" to "content://downloads/2", "mimeType" to "image/png"),
            mapOf("id" to 3L, "uri" to "content://downloads/3", "mimeType" to "image/webp"),
        ))
        assertEquals(listOf(2L, 3L), result.map { it.id })
        assertTrue(result.all { it.mime.startsWith("image/") })
    }

    @Test fun rejectsForeignUrisNonImagesAndOversizedCollections() {
        assertThrows(IllegalArgumentException::class.java) {
            validateGalleryItems(listOf(mapOf("id" to 1, "uri" to "file:///tmp/a.jpg", "mimeType" to "image/jpeg")))
        }
        assertThrows(IllegalArgumentException::class.java) {
            validateGalleryItems(listOf(mapOf("id" to 1, "uri" to "content://downloads/1", "mimeType" to "video/mp4")))
        }
        assertThrows(IllegalArgumentException::class.java) {
            validateGalleryItems(List(21) { mapOf("id" to it, "uri" to "content://downloads/$it", "mimeType" to "image/jpeg") })
        }
    }
}

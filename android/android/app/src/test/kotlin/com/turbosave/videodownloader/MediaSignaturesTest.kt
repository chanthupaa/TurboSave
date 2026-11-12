package com.turbosave.videodownloader

import java.io.ByteArrayInputStream
import org.junit.Assert.*
import org.junit.Test

class MediaSignaturesTest {
    private fun bytes(vararg values: Int) = values.map { it.toByte() }.toByteArray()
    @Test fun acceptsSupportedContainers() {
        for (header in listOf(
            bytes(0,0,0,24) + "ftypisom".toByteArray(),
            bytes(0,0,0,24) + "moov0000".toByteArray(),
            bytes(0x1a,0x45,0xdf,0xa3),
            "ID3".toByteArray() + bytes(4,0,0,0,0,0,0),
            bytes(0xff,0xfb,0x90,0x64),
            "RIFF0000WAVE".toByteArray(),
            "fLaC".toByteArray(),
            "OggS".toByteArray() + ByteArray(23)
        )) assertTrue("Expected a recognised container", hasMediaSignature(header))
    }
    @Test fun rejectsDataPagesAndInvalidHeaders() {
        for (header in listOf(ByteArray(0), "<html>error</html>".toByteArray(), "{\"error\":1}".toByteArray(),
            "not a video".toByteArray(), "PKarchive".toByteArray(), "RIFF0000AVI ".toByteArray(),
            "ID3".toByteArray(), bytes(0xff,0xff,0xff,0xff))) assertFalse(hasMediaSignature(header))
    }
    @Test fun shortNetworkReadsDoNotTruncateTheSignature() {
        val header = bytes(0,0,0,24) + "ftypisom".toByteArray()
        val input = object : ByteArrayInputStream(header) {
            override fun read(buffer: ByteArray, offset: Int, length: Int) = super.read(buffer, offset, minOf(length, 1))
        }
        assertTrue(hasMediaSignature(readMediaPrefix(input)))
    }
    @Test fun acceptsSupportedImagesWithoutTreatingHtmlAsAnImage() {
        assertTrue(hasMediaSignature(bytes(0xff,0xd8,0xff,0xe0)))
        assertTrue(hasMediaSignature(bytes(0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a)))
        assertTrue(hasMediaSignature("RIFF0000WEBPVP8 ".toByteArray()))
        assertFalse(hasMediaSignature("<html><img src='x'>".toByteArray()))
        assertTrue(isDownloadableMime("image/jpeg"))
        assertFalse(isDownloadableMime("text/html"))
    }
}

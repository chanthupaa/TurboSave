package com.turbosave.videodownloader

import java.io.ByteArrayInputStream
import java.net.InetAddress
import java.net.URI
import org.junit.Assert.*
import org.junit.Test

class PublicMediaProbeTest {
    @Test fun internalPlayerAcceptsOnlyVideoAndAudio() {
        assertTrue(isPlayableMime("video/mp4"))
        assertTrue(isPlayableMime("audio/mpeg"))
        assertFalse(isPlayableMime("image/jpeg"))
        assertFalse(isPlayableMime("application/octet-stream"))
        assertFalse(isPlayableMime(""))
    }

    @Test fun explainsRejectedAndExpiredTemporaryLinks() {
        assertTrue(mediaStatusError(403).contains("rejected"))
        assertTrue(mediaStatusError(410).contains("expired"))
        assertTrue(mediaStatusError(503).contains("temporarily unavailable"))
    }

    @Test fun readsBoundedContentLengthAndRepeatedCookies() {
        val data = "HTTP/1.1 206 Partial Content\r\nContent-Type: video/mp4\r\nContent-Length: 12\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\n\r\n".toByteArray() + byteArrayOf(0,0,0,24) + "ftypisom".toByteArray()
        val response = readProbeResponse(ByteArrayInputStream(data))
        assertEquals(206, response.status)
        assertTrue(hasMediaSignature(response.prefix))
    }
    @Test fun decodesChunkedPrefixAcrossSmallChunks() {
        val data = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nfLaC\r\n0\r\n\r\n"
        assertTrue(hasMediaSignature(readProbeResponse(ByteArrayInputStream(data.toByteArray())).prefix))
    }
    @Test fun exposesRedirectWithoutFollowingIt() {
        val response = readProbeResponse(ByteArrayInputStream("HTTP/1.1 302 Found\r\nLocation: https://localhost/private.mp4\r\n\r\n".toByteArray()))
        assertEquals(302, response.status)
        assertEquals("https://localhost/private.mp4", response.headers["location"])
        assertEquals(0, response.prefix.size)
    }
    @Test fun rejectsChangedDnsAnswerBeforeConnecting() {
        var lookups = 0
        val rules = LinkRules(false, emptySet()) {
            lookups++
            arrayOf(InetAddress.getByAddress(if (lookups == 1) byteArrayOf(8,8,8,8) else byteArrayOf(127,0,0,1)))
        }
        val uri = rules.validate("https://example.com/file.mp4")
        try { publicMediaProbe(uri, rules, emptyMap()); fail("Private address accepted") }
        catch (_: IllegalArgumentException) { }
        assertEquals(2, lookups)
    }
    @Test fun rejectsAmbiguousFraming() {
        try { readProbeResponse(ByteArrayInputStream("HTTP/1.1 200 OK\r\nContent-Length: 10\r\nContent-Length: 20\r\n\r\n".toByteArray())); fail("Ambiguous length accepted") }
        catch (_: IllegalArgumentException) { }
    }
}

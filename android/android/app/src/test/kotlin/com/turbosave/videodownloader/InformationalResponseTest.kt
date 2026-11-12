package com.turbosave.videodownloader

import java.io.ByteArrayInputStream
import org.junit.Assert.*
import org.junit.Test

class InformationalResponseTest {
    private val media: ByteArray get() = javaClass.classLoader!!
        .getResourceAsStream("media-signatures/leading-free.mp4")!!.use { it.readBytes() }

    private fun response(hints: String, status: Int = 200, headers: String = ""): ProbeResponse {
        val body = media
        val head = hints + "HTTP/1.1 $status Media\r\nContent-Type: video/mp4\r\n" +
            "Content-Length: ${body.size}\r\n" + headers + "\r\n"
        return readProbeResponse(ByteArrayInputStream(head.toByteArray() + body))
    }

    @Test fun earlyHintsBeforeMediaAreNotTheFinalResponse() {
        val result = response("HTTP/1.1 103 Early Hints\r\nLink: </style.css>; rel=preload\r\n\r\n")
        assertEquals(200, result.status)
        assertEquals(512, result.prefix.size)
        assertTrue(hasMediaSignature(result.prefix))
    }

    @Test fun multipleInformationalResponsesCanPrecedePartialMedia() {
        val hints = "HTTP/1.1 100 Continue\r\n\r\n" +
            "HTTP/1.1 102 Processing\r\n\r\n" +
            "HTTP/1.1 103 Early Hints\r\n\r\n"
        val result = response(hints, 206)
        assertEquals(206, result.status)
        assertTrue(hasMediaSignature(result.prefix))
    }

    @Test fun onlyFinalHeadersDescribeMedia() {
        val hints = "HTTP/1.1 103 Early Hints\r\nContent-Type: text/html\r\n" +
            "Location: https://localhost/private.mp4\r\n\r\n"
        val result = response(hints)
        assertEquals(200, result.status)
        assertEquals("video/mp4", result.headers["content-type"])
        assertFalse(result.headers.containsKey("location"))
    }

    @Test fun finalRedirectAfterHintsIsReturnedForCallerValidation() {
        val data = "HTTP/1.1 103 Early Hints\r\n\r\n" +
            "HTTP/1.1 302 Found\r\nLocation: https://localhost/private.mp4\r\n\r\n"
        val result = readProbeResponse(ByteArrayInputStream(data.toByteArray()))
        assertEquals(302, result.status)
        assertEquals("https://localhost/private.mp4", result.headers["location"])
        assertEquals(0, result.prefix.size)
    }

    @Test fun protocolSwitchIsNotTreatedAsOrdinaryInformationalHeaders() {
        val result = response("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n\r\n")
        assertEquals(101, result.status)
        assertEquals(0, result.prefix.size)
    }

    @Test(expected = IllegalArgumentException::class)
    fun informationalHeadersWithoutFinalResponseAreRejected() {
        readProbeResponse(ByteArrayInputStream("HTTP/1.1 103 Early Hints\r\n\r\n".toByteArray()))
    }

    @Test fun informationalResponseCountIsBounded() {
        try {
            response("HTTP/1.1 103 Early Hints\r\n\r\n".repeat(17))
            fail("Unbounded informational response chain accepted")
        } catch (error: IllegalArgumentException) {
            assertTrue(error.message.orEmpty().contains("informational"))
        }
    }

    @Test fun sixteenInformationalResponsesStillAllowFinalMedia() {
        val result = response("HTTP/1.1 103 Early Hints\r\n\r\n".repeat(16))
        assertEquals(200, result.status)
        assertTrue(hasMediaSignature(result.prefix))
    }

    @Test fun headerBudgetIsSharedAcrossInformationalAndFinalResponses() {
        val hint = "HTTP/1.1 103 Early Hints\r\nX-Pad: " + "x".repeat(7000) + "\r\n\r\n"
        try {
            response(hint.repeat(10))
            fail("Aggregate header limit bypassed")
        } catch (error: IllegalArgumentException) {
            assertTrue(error.message.orEmpty().contains("headers"))
        }
    }

    @Test fun chunkedMediaStillDecodesAfterHints() {
        val data = "HTTP/1.1 103 Early Hints\r\n\r\n" +
            "HTTP/1.1 200 OK\r\nContent-Type: audio/flac\r\nTransfer-Encoding: chunked\r\n\r\n" +
            "4\r\nfLaC\r\n0\r\n\r\n"
        val result = readProbeResponse(ByteArrayInputStream(data.toByteArray()))
        assertEquals(200, result.status)
        assertTrue(hasMediaSignature(result.prefix))
    }
}

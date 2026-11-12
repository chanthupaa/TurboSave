package com.turbosave.videodownloader

import java.io.ByteArrayInputStream
import java.io.InputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong
import org.junit.Assert.*
import org.junit.Test

class NetworkBudgetTest {
    private val media = "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nfLaC".toByteArray()

    @Test fun slowDripCannotRestartTheDeadlineOnEveryRead() {
        val now = AtomicLong()
        var position = 0
        val input = object : InputStream() {
            override fun read(): Int {
                now.addAndGet(5_000_000)
                return if (position < media.size) media[position++].toInt() and 255 else -1
            }
            override fun read(bytes: ByteArray, offset: Int, length: Int): Int {
                val value = read()
                if (value < 0) return -1
                bytes[offset] = value.toByte()
                return 1
            }
        }
        try {
            readProbeResponse(input, NetworkBudget(10, now::get))
            fail("A continuous trickle outlived the operation")
        } catch (error: IllegalStateException) {
            assertTrue(error.message!!.contains("took too long"))
        }
        assertTrue(position <= 2)
    }

    @Test fun redirectsAndLaterStagesShareTheSameBudget() {
        val now = AtomicLong()
        val budget = NetworkBudget(65_000, now::get)
        val redirect = "HTTP/1.1 302 Found\r\nLocation: https://example.com/file.mp4\r\n\r\n"
        assertEquals(302, readProbeResponse(ByteArrayInputStream(redirect.toByteArray()), budget).status)
        now.set(TimeUnit.SECONDS.toNanos(66))
        try { readProbeResponse(ByteArrayInputStream(media), budget); fail("Redirect reset the deadline") }
        catch (_: IllegalStateException) { }
    }

    @Test fun expiredQueuedWorkNeverStartsDns() {
        val now = AtomicLong()
        val budget = NetworkBudget(1, now::get)
        now.set(2_000_000)
        var called = false
        val rules = LinkRules(false, emptySet()) { called = true; emptyArray() }
        try { rules.validate("https://example.com/file.mp4", budget); fail("Expired work started") }
        catch (_: IllegalStateException) { }
        assertFalse(called)
    }

    @Test fun timeSpentInDnsCountsAgainstTheDeadline() {
        val now = AtomicLong()
        val rules = LinkRules(false, emptySet()) {
            now.set(TimeUnit.SECONDS.toNanos(66))
            arrayOf(InetAddress.getByAddress(byteArrayOf(8, 8, 8, 8)))
        }
        try { rules.validate("https://example.com/file.mp4", NetworkBudget(65_000, now::get)); fail("DNS exceeded the deadline") }
        catch (_: IllegalStateException) { }
    }

    @Test fun deadlineActuallyClosesABlockedSocket() {
        val executor = Executors.newSingleThreadExecutor()
        ServerSocket(0, 1, InetAddress.getLoopbackAddress()).use { server ->
            Socket(InetAddress.getLoopbackAddress(), server.localPort).use { client ->
                server.accept().use { peer ->
                    val started = CountDownLatch(1)
                    val read = executor.submit<Boolean> {
                        started.countDown()
                        try { client.getInputStream().read(); false }
                        catch (_: Exception) { client.isClosed }
                    }
                    try {
                        assertTrue(started.await(2, TimeUnit.SECONDS))
                        NetworkBudget(100).closeAtDeadline(client).use {
                            assertTrue(read.get(3, TimeUnit.SECONDS))
                        }
                        assertFalse(peer.isClosed)
                    } finally { executor.shutdownNow() }
                }
            }
        }
    }

    @Test fun aWorkerAcceptsAValidOperationAfterATimeout() {
        val executor = Executors.newSingleThreadExecutor()
        try {
            executor.submit {
                try { readProbeResponse(ByteArrayInputStream(media), NetworkBudget(0)); fail("Expired read succeeded") }
                catch (_: IllegalStateException) { }
            }.get(2, TimeUnit.SECONDS)
            val result = executor.submit<ProbeResponse> { readProbeResponse(ByteArrayInputStream(media)) }.get(2, TimeUnit.SECONDS)
            assertTrue(hasMediaSignature(result.prefix))
        } finally { executor.shutdownNow() }
    }

    @Test fun excessiveDnsAnswersAreRejectedRatherThanTruncated() {
        val rules = LinkRules(false, emptySet()) {
            Array(65) { InetAddress.getByAddress(byteArrayOf(8, 8, 8, 8)) }
        }
        try { rules.validate("https://example.com/file.mp4"); fail("Excessive DNS answers accepted") }
        catch (_: IllegalArgumentException) { }
    }
}

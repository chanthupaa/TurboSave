package com.turbosave.videodownloader

import java.io.ByteArrayInputStream
import java.util.Random
import org.junit.Assert.*
import org.junit.Test

class MediaSignatureBoundsTest {
    private fun word(value: Long, count: Int = 4) = ByteArray(count) {
        (value ushr ((count - it - 1) * 8)).toByte()
    }
    private fun header(type: String, size: Long) = word(size) + type.toByteArray(Charsets.US_ASCII)
    private fun box(type: String, payload: ByteArray = ByteArray(0)) = header(type, (8 + payload.size).toLong()) + payload
    private val ftyp = header("ftyp", 24) + "isom".toByteArray()
    private fun rf64() = "RF64".toByteArray() + ByteArray(4) { -1 } +
        "WAVEds64".toByteArray() + byteArrayOf(28, 0, 0, 0) + ByteArray(28)

    @Test fun acceptsPermittedPaddingBeforeARecognisedMp4Box() {
        for (type in listOf("free", "skip", "wide")) {
            assertTrue(type, hasMediaSignature(box(type) + ftyp))
        }
        assertTrue(hasMediaSignature(box("free") + box("skip", ByteArray(4)) + box("wide") + ftyp))
    }

    @Test fun acceptsExtendedSizePaddingAndMediaHeaders() {
        val extendedFree = header("free", 1) + word(16, 8)
        assertTrue(hasMediaSignature(extendedFree + ftyp))
        val extendedFtyp = header("ftyp", 1) + word(32, 8) + "isom".toByteArray()
        assertTrue(hasMediaSignature(extendedFtyp))
    }

    @Test fun rejectsZeroUndersizedAndOversizedPaddingLengths() {
        for (size in listOf(0L, 2L, 3L, 4L, 5L, 6L, 7L, 513L, 0x80000000L, 0xffffffffL)) {
            assertFalse("size $size", hasMediaSignature(header("free", size) + ftyp))
        }
    }

    @Test fun rejectsInvalidExtendedSizesWithoutOverflow() {
        for (size in listOf(0L, 8L, 15L, Long.MAX_VALUE, Long.MIN_VALUE, -1L)) {
            assertFalse("size $size", hasMediaSignature(header("free", 1) + word(size, 8) + ftyp))
        }
        assertFalse(hasMediaSignature(header("ftyp", 1) + word(8, 8) + "isom".toByteArray()))
    }

    @Test fun truncatedHeadersAndPaddingCannotExposeAMediaSignature() {
        val prefix = box("free") + ftyp
        for (length in 0 until prefix.size) {
            assertFalse("length $length", hasMediaSignature(prefix.copyOf(length)))
        }
        assertFalse(hasMediaSignature(header("free", 32) + ftyp))
    }

    @Test fun unknownLeadingBoxesAndPaddingAloneAreRejected() {
        assertFalse(hasMediaSignature(box("junk") + ftyp))
        for (type in listOf("free", "skip", "wide")) {
            assertFalse(hasMediaSignature(box(type, ByteArray(8))))
        }
    }

    @Test fun boxCountIsBoundedEvenWithinThePrefix() {
        val fifteen = ByteArray(0).let { empty -> (1..15).fold(empty) { bytes, _ -> bytes + box("free") } }
        assertTrue(hasMediaSignature(fifteen + ftyp))
        assertFalse(hasMediaSignature(fifteen + box("free") + ftyp))
    }

    @Test fun neverScansPastThe512ByteProbeWindow() {
        assertTrue(hasMediaSignature(box("free", ByteArray(492)) + ftyp))
        assertFalse(hasMediaSignature(box("free", ByteArray(504)) + ftyp))
    }

    @Test fun doesNotSearchPaddingPayloadForMagicStrings() {
        val payload = "ftypisom".toByteArray() + ByteArray(16)
        assertFalse(hasMediaSignature(box("free", payload) + "{\"error\":true}".toByteArray()))
    }

    @Test fun htmlJsonAndMalformedFtypRemainRejected() {
        for (bytes in listOf(
            "<html>ftypisom</html>".toByteArray(),
            "{\"type\":\"ftyp\",\"error\":true}".toByteArray(),
            header("ftyp", 4) + "isom".toByteArray(),
            header("ftyp", 8) + "isom".toByteArray(),
            header("ftyp", 24),
        )) assertFalse(hasMediaSignature(bytes))
    }

    @Test fun rf64NeedsTheSentinelWaveAndMandatoryDs64Header() {
        val valid = rf64()
        assertTrue(hasMediaSignature(valid))
        for (position in listOf(4, 5, 6, 7, 8, 12)) {
            val invalid = valid.copyOf().apply { this[position] = 0 }
            assertFalse("position $position", hasMediaSignature(invalid))
        }
        assertFalse(hasMediaSignature("RF64".toByteArray() + ByteArray(4) { -1 } + "AVI ds64".toByteArray() + ByteArray(32)))
    }

    @Test fun truncatedRf64HeadersStayRejected() {
        val valid = rf64()
        for (length in 0 until 48) assertFalse("length $length", hasMediaSignature(valid.copyOf(length)))
    }

    @Test fun independentlyGeneratedFixturesPassTheActualBoundedReader() {
        for (name in listOf("leading-free.mp4", "rf64.wav")) {
            val stream = requireNotNull(javaClass.getResourceAsStream("/media-signatures/$name"))
            stream.use {
                val prefix = readMediaPrefix(it)
                assertEquals(512, prefix.size)
                assertTrue(name, hasMediaSignature(prefix))
            }
        }
    }

    @Test fun slowShortReadsStillStopAt512Bytes() {
        val data = box("free", ByteArray(492)) + ftyp + ByteArray(4096)
        val input = object : ByteArrayInputStream(data) {
            override fun read(buffer: ByteArray, offset: Int, length: Int) = super.read(buffer, offset, minOf(1, length))
        }
        val prefix = readMediaPrefix(input)
        assertTrue(hasMediaSignature(prefix))
        assertEquals(data.size - 512, input.available())
    }

    @Test(timeout = 10_000) fun randomAndMutatedHeadersNeverThrowOrLoopIndefinitely() {
        val random = Random(20261030)
        repeat(10_000) {
            val bytes = ByteArray(random.nextInt(1025)).also(random::nextBytes)
            hasMediaSignature(bytes)
            val malformed = header("free", random.nextLong()) + bytes + ftyp
            hasMediaSignature(malformed)
        }
    }
}

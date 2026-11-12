package com.turbosave.videodownloader

import org.junit.Assert.assertTrue
import org.junit.Test

/** Audit only: both container layouts were independently verified with FFprobe. */
class SecondMediaAuditTest {
    @Test fun acceptsMp4WithAValidLeadingFreeBox() {
        val prefix = byteArrayOf(0,0,0,8) + "free".toByteArray() + byteArrayOf(0,0,0,32) + "ftypisom".toByteArray()
        assertTrue("A legal leading free box must not make a valid MP4 unavailable", hasMediaSignature(prefix))
    }
    @Test fun acceptsRf64WaveFiles() {
        val prefix = "RF64".toByteArray() + byteArrayOf(-1,-1,-1,-1) + "WAVEds64".toByteArray() + ByteArray(32)
        assertTrue("RF64 is a valid WAV container", hasMediaSignature(prefix))
    }
}

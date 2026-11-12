package com.turbosave.videodownloader

import android.app.DownloadManager
import org.junit.Assert.assertEquals
import org.junit.Test

class AdaptiveTransfersTest {
    @Test fun combinesBytesAndWaitsForBothParts() {
        val video = PartState(DownloadManager.STATUS_SUCCESSFUL, 100, 100)
        val audio = PartState(DownloadManager.STATUS_RUNNING, 20, 50)
        val progress = combinedParts(video, audio)
        assertEquals("downloading", progress["status"])
        assertEquals(120L, progress["bytes"])
        assertEquals(150L, progress["total"])
        assertEquals("merging", combinedParts(video, audio.copy(status = DownloadManager.STATUS_SUCCESSFUL))["status"])
    }

    @Test fun failureAndUnknownSizeAreReported() {
        val video = PartState(DownloadManager.STATUS_RUNNING, 10, -1)
        val audio = PartState(DownloadManager.STATUS_FAILED, 0, -1, 403)
        val result = combinedParts(video, audio)
        assertEquals("failed", result["status"])
        assertEquals(-1L, result["total"])
        assertEquals(true, (result["error"] as String).contains("403"))
        assertEquals("failed", combinedParts(video, null)["status"])
    }
}

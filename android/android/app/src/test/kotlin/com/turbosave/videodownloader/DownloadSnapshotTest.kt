package com.turbosave.videodownloader

import org.junit.Assert.assertEquals
import org.junit.Test

class DownloadSnapshotTest {
    @Test fun unknownDownloadDoesNotDiscardOtherSnapshots() {
        val result = queryDownloadSnapshots(listOf(101L, 102L)) { id ->
            if (id == 101L) mapOf("id" to id, "status" to "unknown")
            else mapOf("id" to id, "status" to "completed", "uri" to "content://downloads/$id")
        }
        assertEquals(listOf(101L, 102L), result.map { it["id"] })
        assertEquals(listOf("unknown", "completed"), result.map { it["status"] })
    }

    @Test fun snapshotExceptionIsIsolatedAndReportedForItsOwnId() {
        val result = queryDownloadSnapshots(listOf(101L, 102L)) { id ->
            if (id == 101L) throw SecurityException("Unreadable record")
            mapOf("id" to id, "status" to "downloading")
        }
        assertEquals("error", result[0]["status"])
        assertEquals(101L, result[0]["id"])
        assertEquals("SecurityException", result[0]["errorType"])
        assertEquals("downloading", result[1]["status"])
    }
}

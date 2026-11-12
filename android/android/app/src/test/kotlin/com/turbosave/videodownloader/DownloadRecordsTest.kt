package com.turbosave.videodownloader

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class DownloadRecordsTest {
    private var savedOwned = emptySet<Long>()
    private var savedPending = emptySet<Long>()
    private fun records(owned: Set<Long>, pending: Set<Long> = emptySet()) =
        DownloadRecords(owned, pending) { ids, unacknowledged ->
            savedOwned = ids; savedPending = unacknowledged
        }

    @Test fun largeHistoricalMetadataShrinksToRetainedLibraryAndQueue() {
        val history = (1L..10_000L).toSet()
        val retained = (9_901L..10_000L).toSet() + 10_001L
        val records = records(history + 10_001L)
        records.reconcile(retained) { it }
        assertEquals(retained, savedOwned)
        assertEquals(emptySet<Long>(), savedPending)
        assertFalse(records.contains(1L))
        assertTrue(records.contains(10_001L))
    }

    @Test fun openingTheLastIdDoesOneUriLookupRegardlessOfHistorySize() {
        val records = records((1L..100_000L).toSet())
        var lookups = 0
        records.requireUri(100_000L, "content://downloads/100000") { id ->
            lookups++; assertEquals(100_000L, id); "content://downloads/$id"
        }
        assertEquals(1, lookups)
    }

    @Test fun aSuppliedIdDoesNotGrantOwnership() {
        val records = records(setOf(1L))
        try {
            records.requireUri(2L, "content://downloads/2") { fail("Looked up an unowned ID"); null }
            fail("Unowned ID was accepted")
        } catch (_: IllegalArgumentException) { }
        records.reconcile(setOf(2L)) { emptySet() }
        assertFalse(records.contains(2L))
    }

    @Test fun aUriForAnotherFileIsRejectedEvenWithAnOwnedId() {
        val records = records(setOf(1L, 2L))
        for (uri in listOf("content://downloads/2", "content://foreign/file", "file:///tmp/clip.mp4")) {
            try {
                records.requireUri(1L, uri) { "content://downloads/1" }
                fail("URI mismatch was accepted")
            } catch (_: IllegalArgumentException) { }
        }
    }

    @Test fun clearingMetadataPreservesUnlistedActiveTransfers() {
        val records = records(setOf(1L, 2L, 3L))
        records.reconcile(emptySet()) { it - 3L }
        assertEquals(setOf(3L), savedOwned)
    }

    @Test fun acceptedButUnacknowledgedEnqueueSurvivesStaleReconciliation() {
        val records = records(emptySet())
        records.add(7L)
        records.reconcile(emptySet()) { it }
        assertTrue(records.contains(7L))
        assertEquals(setOf(7L), savedPending)
        records.reconcile(setOf(7L)) { it }
        assertTrue(records.contains(7L))
        assertTrue(savedPending.isEmpty())
        records.reconcile(emptySet()) { it }
        assertTrue(savedOwned.isEmpty())
    }

    @Test fun restartRetainsUnacknowledgedNativeJobs() {
        val original = records(emptySet())
        original.add(8L)
        val restarted = records(savedOwned, savedPending)
        restarted.reconcile(emptySet()) { it }
        assertTrue(restarted.contains(8L))
        restarted.reconcile(setOf(8L)) { it }
        restarted.reconcile(emptySet()) { it }
        assertFalse(restarted.contains(8L))
    }

    @Test fun retainedFailedTasksAndUnlistedLiveJobsRemainRecoverable() {
        val records = records(setOf(1L, 2L, 3L))
        val queried = mutableListOf<Long>()
        records.reconcile(setOf(1L)) { ids -> queried.addAll(ids); ids.intersect(setOf(3L)) }
        assertEquals(listOf(2L, 3L), queried)
        assertEquals(setOf(1L, 2L), savedOwned)
    }

    @Test fun queryFailureDoesNotPartiallyForgetRecords() {
        val records = records(setOf(1L, 2L))
        try {
            records.reconcile(emptySet()) { error("Query unavailable") }
            fail("Expected query failure")
        } catch (_: IllegalStateException) { }
        assertTrue(records.contains(1L))
        assertTrue(records.contains(2L))
    }

    @Test fun pruningCannotRemoveRetainedOrUnacknowledgedIds() {
        val records = records(setOf(1L, 2L))
        records.add(3L)
        records.reconcile(setOf(1L)) { setOf(1L, 2L, 3L, 99L) }
        assertEquals(setOf(1L, 3L), savedOwned)
        assertEquals(setOf(3L), savedPending)
    }

    @Test fun verificationCacheIsPrunedWithOwnership() {
        val records = records(setOf(1L, 2L))
        var reads = 0
        assertTrue(records.verify(1L) { reads++; true })
        assertTrue(records.verify(1L) { fail("Repeated cached verification"); false })
        records.reconcile(setOf(2L)) { it }
        assertFalse(records.verify(1L) { fail("Verified an unowned file"); true })
        records.add(1L)
        assertTrue(records.verify(1L) { reads++; true })
        assertEquals(2, reads)
    }

    @Test fun cancelForgetsOwnershipPendingStateAndCachedVerification() {
        val records = records(emptySet())
        records.add(9L)
        records.verify(9L) { true }
        records.forget(9L)
        assertTrue(savedOwned.isEmpty())
        assertTrue(savedPending.isEmpty())
        assertFalse(records.verify(9L) { fail("Stale cache retained"); true })
    }

    @Test fun concurrentEnqueuesAndPruningPreserveEveryUnacknowledgedId() {
        val records = records(emptySet())
        val pool = Executors.newFixedThreadPool(2)
        val start = CountDownLatch(1)
        try {
            val enqueue = pool.submit { start.await(); for (id in 1L..1_000L) records.add(id) }
            val cleanup = pool.submit { start.await(); repeat(100) { records.reconcile(emptySet()) { it } } }
            start.countDown()
            enqueue.get(10, TimeUnit.SECONDS); cleanup.get(10, TimeUnit.SECONDS)
            assertEquals((1L..1_000L).toSet(), savedOwned)
            assertEquals(savedOwned, savedPending)
        } finally { pool.shutdownNow() }
    }
}

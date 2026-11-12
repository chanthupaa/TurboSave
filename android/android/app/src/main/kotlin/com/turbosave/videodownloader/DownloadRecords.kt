package com.turbosave.videodownloader

/** Ownership metadata only: forgetting a record never removes its downloaded file. */
internal class DownloadRecords(
    initialOwned: Set<Long>,
    initialUnacknowledged: Set<Long>,
    private val persist: (Set<Long>, Set<Long>) -> Unit,
) {
    private val owned = initialOwned.toMutableSet()
    private val unacknowledged = initialUnacknowledged.intersect(owned).toMutableSet()
    private val verified = mutableMapOf<Long, Boolean>()

    @Synchronized fun contains(id: Long): Boolean = id in owned

    @Synchronized fun add(id: Long) {
        owned.add(id)
        // A concurrent save may not contain this ID until enqueue returns to Dart.
        unacknowledged.add(id)
        save()
    }

    @Synchronized fun forget(id: Long) {
        owned.remove(id)
        unacknowledged.remove(id)
        verified.remove(id)
        save()
    }

    @Synchronized fun verify(id: Long, inspect: () -> Boolean): Boolean =
        id in owned && verified.getOrPut(id, inspect)

    @Synchronized fun requireUri(id: Long, uri: String, downloadedUri: (Long) -> String?) {
        require(id in owned) { "This download does not belong to this app." }
        require(downloadedUri(id) == uri) { "This file was moved or removed." }
    }

    @Synchronized fun reconcile(retained: Set<Long>, removable: (Set<Long>) -> Set<Long>) {
        val acknowledged = unacknowledged.intersect(retained)
        val candidates = owned - retained - unacknowledged
        // Finish the status query before changing any state: query failure preserves ownership.
        val forgotten = if (candidates.isEmpty()) emptySet() else removable(candidates).intersect(candidates)
        if (acknowledged.isEmpty() && forgotten.isEmpty()) return
        unacknowledged.removeAll(acknowledged)
        owned.removeAll(forgotten)
        verified.keys.removeAll(forgotten)
        save()
    }

    private fun save() = persist(owned.toSet(), unacknowledged.toSet())
}

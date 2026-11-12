package com.turbosave.videodownloader

import android.Manifest
import android.app.DownloadManager
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val workers = ThreadPoolExecutor(2, 2, 20, TimeUnit.SECONDS, ArrayBlockingQueue<Runnable>(6)).apply { allowCoreThreadTimeOut(true) }
    private val extracting = AtomicBoolean(false)
    private var shareChannel: MethodChannel? = null
    private var permissionRequest: Pair<MethodCall, MethodChannel.Result>? = null
    private val saved by lazy { getSharedPreferences("native_transfers_v1", MODE_PRIVATE) }
    private val downloads by lazy { getSystemService(DOWNLOAD_SERVICE) as DownloadManager }
    private val adaptive by lazy { AdaptiveTransfers(applicationContext, downloads) }
    private val records by lazy {
        DownloadRecords(
            saved.getStringSet("owned_ids", emptySet())!!.mapNotNull { it.toLongOrNull() }.toSet(),
            saved.getStringSet("unacknowledged_ids", emptySet())!!.mapNotNull { it.toLongOrNull() }.toSet(),
        ) { owned, unacknowledged ->
            check(saved.edit().putStringSet("owned_ids", owned.map { it.toString() }.toSet())
                .putStringSet("unacknowledged_ids", unacknowledged.map { it.toString() }.toSet()).commit()) {
                "Could not save download ownership."
            }
        }
    }
    private val rules by lazy {
        val hosts = assets.open("restricted_hosts.json").bufferedReader().use { JSONArray(it.readText()) }
        LinkRules(BuildConfig.RESTRICTED_SOURCES, (0 until hosts.length()).map { hosts.getString(it) }.toSet())
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "turbosave/downloads").setMethodCallHandler { call, result ->
            if (call.method == "supportsAdaptive") {
                result.success(Build.VERSION.SDK_INT >= 29)
            } else if (call.method == "enqueue" && Build.VERSION.SDK_INT <= 28 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                if (permissionRequest != null) { result.error("BUSY", "Finish the storage permission request first.", null) }
                else { permissionRequest = Pair(call, result); requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 6104) }
            } else dispatch(call, result)
        }
        shareChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "turbosave/share").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingShares" -> result.success(pendingShares().let { items -> (0 until items.length()).map { i -> val item = items.getJSONObject(i); mapOf("id" to item.getString("id"), "text" to item.getString("text")) } })
                    "acknowledgeShare" -> {
                        val id = call.argument<String>("id")
                        val old = pendingShares(); val next = JSONArray()
                        for (i in 0 until old.length()) if (old.getJSONObject(i).optString("id") != id) next.put(old.getJSONObject(i))
                        saved.edit().putString("shares", next.toString()).apply(); result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        receiveShare(intent)
        try { workers.execute { adaptive.resumePending() } } catch (_: java.util.concurrent.RejectedExecutionException) { }
    }

    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); receiveShare(intent) }
    private fun pendingShares(): JSONArray = try { JSONArray(saved.getString("shares", "[]")) } catch (_: Exception) { JSONArray() }
    private fun receiveShare(value: Intent?) {
        if (value?.action != Intent.ACTION_SEND || value.type !in listOf("text/plain", "text/uri-list")) return
        val text = value.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.take(8193) ?: return
        if (text.isBlank()) return
        val item = JSONObject().put("id", UUID.randomUUID().toString()).put("text", text)
        val old = pendingShares(); val next = JSONArray()
        for (i in maxOf(0, old.length() - 3) until old.length()) next.put(old.getJSONObject(i))
        next.put(item)
        saved.edit().putString("shares", next.toString()).apply()
        shareChannel?.invokeMethod("sharedLink", mapOf("id" to item.getString("id"), "text" to text))
        // Consume the intent's payload once; activity recreation uses the persisted inbox.
        value.action = Intent.ACTION_MAIN; value.removeExtra(Intent.EXTRA_TEXT)
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code, permissions, grants)
        if (code != 6104) return
        val pending = permissionRequest; permissionRequest = null
        if (pending != null) {
            if (grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) dispatch(pending.first, pending.second)
            else pending.second.error("PERMISSION", "Storage permission is needed to save in Downloads on this Android version.", null)
        }
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf("extract", "inspect", "enqueue", "query", "cancel", "reconcile", "open", "share", "openGallery")) { result.notImplemented(); return }
        val budget = NetworkBudget()
        try {
            workers.execute {
                try {
                    val answer: Any? = when (call.method) {
                        "extract" -> extract(call.argument<String>("url") ?: "", budget)
                        "inspect" -> inspect(call.argument<String>("url") ?: "", emptyMap(), budget)
                        "enqueue" -> enqueue(call, budget)
                        "query" -> queryDownloadSnapshots((call.argument<List<Number>>("ids") ?: emptyList()).map { it.toLong() }, ::snapshot)
                        "cancel" -> { cancel((call.argument<Number>("id") ?: error("Missing download ID")).toLong()); null }
                        "reconcile" -> { reconcile(call, budget); null }
                        "open", "share" -> { openFile(call); null }
                        "openGallery" -> { openGallery(call); null }
                        else -> null
                    }
                    runOnUiThread { if (!isDestroyed) result.success(answer) }
                } catch (error: Exception) {
                    val text = when (error) {
                        is IllegalArgumentException, is IllegalStateException -> error.message?.take(220) ?: "This operation is unavailable."
                        else -> "The source could not be reached. Check your connection or try a different available file."
                    }
                    runOnUiThread { if (!isDestroyed) result.error("MEDIA_ERROR", text, null) }
                }
            }
        } catch (_: java.util.concurrent.RejectedExecutionException) { result.error("BUSY", "Wait for the current source check to finish.", null) }
    }

    private fun extract(value: String, budget: NetworkBudget): String {
        rules.validate(value, budget)
        check(extracting.compareAndSet(false, true)) { "Another link is being checked. Please wait." }
        try {
            synchronized(PYTHON_LOCK) { if (!Python.isStarted()) Python.start(AndroidPlatform(applicationContext)) }
            val response = Python.getInstance().getModule("media_extractor").callAttr("extract", value, BuildConfig.RESTRICTED_SOURCES, budget.remainingMillis() / 1000.0).toString()
            budget.check()
            return response
        } finally { extracting.set(false) }
    }

    private fun cleanHeaders(raw: Map<*, *>, budget: NetworkBudget): Map<String, String> = raw.entries.mapNotNull { (key, value) ->
        val name = key?.toString()?.lowercase() ?: return@mapNotNull null
        val limit = if (name == "cookie") 4096 else 1000
        if (name !in setOf("user-agent", "referer", "accept", "cookie") || value !is String || value.length > limit || value.any { it == '\r' || it == '\n' || it == '\u0000' }) return@mapNotNull null
        if (name == "referer") rules.validate(value, budget)
        name to value
    }.toMap()

    private fun inspect(value: String, headers: Map<String, String>, budget: NetworkBudget): Map<String, Any> {
        var uri = rules.validate(value, budget)
        var requestHeaders = headers
        repeat(5) {
            val response = publicMediaProbe(uri, rules, requestHeaders, budget)
                val code = response.status
                if (code in listOf(301, 302, 303, 307, 308)) {
                    val next = response.headers["location"] ?: error("The source returned an invalid redirect.")
                    val destination = rules.validate(uri.resolve(next).toString(), budget)
                    if (!uri.host.equals(destination.host, ignoreCase = true)) {
                        requestHeaders = requestHeaders.filterKeys { it != "cookie" }
                    }
                    uri = destination
                } else {
                    require(code == 200 || code == 206) { mediaStatusError(code) }
                    val mime = response.headers["content-type"].orEmpty().substringBefore(';').lowercase()
                    require(isDownloadableMime(mime)) { "The source returned a page or data response instead of media." }
                    val bytes = response.prefix
                    require(isMediaBytes(bytes)) { "The source returned an error page instead of media." }
                    val rangeTotal = response.headers["content-range"]?.substringAfterLast('/')?.toLongOrNull()
                    val total = rangeTotal ?: if (code == 200) response.headers["content-length"]?.toLongOrNull() ?: -1L else -1L
                    return mapOf("url" to uri.toString(), "mime" to mime, "bytes" to total)
                }
        }
        error("The source redirected too many times.")
    }

    private fun enqueue(call: MethodCall, budget: NetworkBudget): Long {
        budget.check()
        val value = call.argument<String>("url") ?: ""
        val ext = call.argument<String>("ext")?.lowercase() ?: URI(value).path.substringAfterLast('.').lowercase()
        require(ext in LinkRules.extensions) { "Choose an available video, audio, or image file." }
        val headers = cleanHeaders(call.argument<Map<*, *>>("headers") ?: emptyMap<Any, Any>(), budget)
        val metadata = inspect(value, headers, budget)
        val audioUrl = call.argument<String>("audioUrl")?.takeIf { it.isNotBlank() }
        if (audioUrl != null) {
            require(Build.VERSION.SDK_INT >= 29) { "Adaptive downloads require Android 10 or newer." }
            require(ext == "mp4") { "Adaptive downloads require MP4 video." }
        }
        val audioHeaders = if (audioUrl != null) cleanHeaders(call.argument<Map<*, *>>("audioHeaders") ?: emptyMap<Any, Any>(), budget) else emptyMap()
        val audioMetadata = audioUrl?.let { inspect(it, audioHeaders, budget) }
        if (audioMetadata != null) {
            require(metadata["mime"] == "video/mp4") { "The video source must be MP4 media." }
            require(audioMetadata["mime"] in setOf("audio/mp4", "audio/x-m4a", "audio/m4a", "video/mp4")) { "The audio source must be M4A media." }
        }
        val title = (call.argument<String>("name") ?: "TurboSave media").replace(Regex("[\\p{Cntrl}/\\\\:*?\"<>|]"), "_").trim().trim('.').take(85).ifBlank { "TurboSave media" }
        val name = "$title-${UUID.randomUUID().toString().take(8)}.$ext"
        val request = DownloadManager.Request(Uri.parse(metadata["url"].toString()))
            .setTitle(title).setDescription("TurboSave · ${ext.uppercase()}")
            .setMimeType(metadata["mime"].toString())
            .apply { if (audioUrl == null) setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "TurboSave/$name")
                else setDestinationInExternalFilesDir(this@MainActivity, Environment.DIRECTORY_DOWNLOADS, "adaptive-$name") }
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(call.argument<Boolean>("wifiOnly") != true)
            .setAllowedOverRoaming(false)
        if (call.argument<Boolean>("wifiOnly") == true) request.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
        headers.forEach { (key, value) -> request.addRequestHeader(key, value) }
        budget.check()
        val id = downloads.enqueue(request)
        records.add(id)
        if (audioMetadata != null) {
            var audioId: Long? = null
            try {
                adaptive.start(id, name)
                val audioRequest = DownloadManager.Request(Uri.parse(audioMetadata["url"].toString()))
                    .setTitle(title).setDescription("TurboSave · audio part")
                    .setMimeType(audioMetadata["mime"].toString())
                    .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "adaptive-$id.m4a")
                    .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                    .setAllowedOverMetered(call.argument<Boolean>("wifiOnly") != true)
                    .setAllowedOverRoaming(false)
                if (call.argument<Boolean>("wifiOnly") == true) audioRequest.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
                audioHeaders.forEach { (key, value) -> audioRequest.addRequestHeader(key, value) }
                audioId = downloads.enqueue(audioRequest)
                adaptive.add(id, audioId, name)
            } catch (failure: Exception) {
                downloads.remove(id)
                audioId?.let { downloads.remove(it) }
                adaptive.discard(id)
                records.forget(id)
                throw failure
            }
        }
        return id
    }

    private fun snapshot(id: Long): Map<String, Any?> {
        if (!records.contains(id)) return mapOf("id" to id, "status" to "unknown")
        if (adaptive.get(id) != null) return adaptive.query(id)
        downloads.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
            if (!cursor.moveToFirst()) return mapOf("id" to id, "status" to "failed", "error" to "This Android download record was removed.")
            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
            val bytes = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
            val total = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            val uri = if (status == DownloadManager.STATUS_SUCCESSFUL) downloads.getUriForDownloadedFile(id) else null
            val readable = if (uri == null) false else records.verify(id) { try { contentResolver.openInputStream(uri)?.use { isMediaBytes(readMediaPrefix(it)) } == true } catch (_: Exception) { false } }
            val state = when (status) {
                DownloadManager.STATUS_SUCCESSFUL -> if (readable) "completed" else "failed"
                DownloadManager.STATUS_FAILED -> "failed"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_RUNNING -> "downloading"
                else -> "queued"
            }
            return mapOf("id" to id, "status" to state, "bytes" to bytes, "total" to total, "uri" to if (readable) uri.toString() else null,
                "error" to when { status == DownloadManager.STATUS_SUCCESSFUL && !readable -> "The saved file is missing or is not a media file."; state == "failed" -> "Android could not complete this download (code $reason)."; state == "paused" -> "Waiting for a permitted network or Android to resume."; else -> null })
        }
    }

    private fun cancel(id: Long) {
        require(records.contains(id)) { "This download does not belong to this app." }
        if (adaptive.get(id) != null) adaptive.cancel(id) else downloads.remove(id)
        records.forget(id)
    }

    private fun reconcile(call: MethodCall, budget: NetworkBudget) {
        val retained = call.argument<List<Number>>("ids") ?: error("Missing retained download IDs")
        require(retained.size <= 120) { "Too many retained download records." }
        records.reconcile(retained.map { it.toLong() }.toSet()) { candidates ->
            val removable = candidates.filterNot { adaptive.get(it) != null }.toMutableSet()
            for (batch in removable.toList().chunked(100)) {
                budget.check()
                downloads.query(DownloadManager.Query().setFilterById(*batch.toLongArray())).use { cursor ->
                    while (cursor.moveToNext()) {
                        budget.check()
                        val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                        if (status != DownloadManager.STATUS_SUCCESSFUL && status != DownloadManager.STATUS_FAILED) {
                            removable.remove(cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_ID)))
                        }
                    }
                }
            }
            removable
        }
    }

    private fun openFile(call: MethodCall) {
        val uri = Uri.parse(call.argument<String>("uri") ?: "")
        require(uri.scheme == "content") { "Only files saved by TurboSave can be opened." }
        val id = (call.argument<Number>("id") ?: error("Missing download ID")).toLong()
        records.requireUri(id, uri.toString()) { adaptive.finalUri(it) ?: downloads.getUriForDownloadedFile(it)?.toString() }
        require(snapshot(id)["status"] == "completed") { "This file is not available." }
        val mime = call.argument<String>("mimeType").orEmpty()
        require(isViewableMime(mime)) { "This media type is not supported." }
        runOnUiThread {
            try {
                val action = if (call.method == "share") Intent(Intent.ACTION_SEND).apply { type = mime; putExtra(Intent.EXTRA_STREAM, uri); clipData = ClipData.newRawUri("TurboSave media", uri) }
                    else Intent(this, PlayerActivity::class.java).setDataAndType(uri, mime)
                action.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                startActivity(if (call.method == "share") Intent.createChooser(action, "Share saved media") else action)
            } catch (_: Exception) { android.widget.Toast.makeText(this, "TurboSave could not open this file.", android.widget.Toast.LENGTH_LONG).show() }
        }
    }

    private fun openGallery(call: MethodCall) {
        val items = validateGalleryItems(call.argument<List<*>>("items") ?: emptyList<Any>())
        val uris = ArrayList<Uri>()
        for (item in items) {
            val uri = Uri.parse(item.uri)
            records.requireUri(item.id, item.uri) { downloads.getUriForDownloadedFile(it)?.toString() }
            require(snapshot(item.id)["status"] == "completed") { "A slideshow image is not available." }
            uris.add(uri)
        }
        runOnUiThread {
            try {
                val intent = Intent(this, PlayerActivity::class.java).apply {
                    putParcelableArrayListExtra("galleryUris", uris)
                    putStringArrayListExtra("galleryMimes", ArrayList(items.map { it.mime }))
                    clipData = ClipData.newRawUri("TurboSave slideshow", uris.first()).apply {
                        for (uri in uris.drop(1)) addItem(ClipData.Item(uri))
                    }
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(intent)
            } catch (_: Exception) {
                android.widget.Toast.makeText(this, "TurboSave could not open this slideshow.", android.widget.Toast.LENGTH_LONG).show()
            }
        }
    }

    override fun onDestroy() {
        permissionRequest?.second?.error("CLOSED", "The app closed before the permission request finished.", null)
        permissionRequest = null; shareChannel?.setMethodCallHandler(null); shareChannel = null
        workers.shutdownNow()
        super.onDestroy()
    }
    companion object {
        private val PYTHON_LOCK = Any()
        fun isMediaBytes(bytes: ByteArray): Boolean {
            return hasMediaSignature(bytes)
        }
    }
}

internal fun mediaStatusError(status: Int): String = when (status) {
    401, 403 -> "The source rejected this temporary media link. Refresh the formats and try again."
    404, 410 -> "This temporary media link expired. Refresh the formats and try again."
    in 400..499 -> "The source rejected this media request (HTTP $status)."
    in 500..599 -> "The source is temporarily unavailable (HTTP $status)."
    else -> "The source returned an unexpected media response (HTTP $status)."
}

// One stale or unreadable record must not discard the other download states.
internal fun queryDownloadSnapshots(ids: List<Long>, snapshot: (Long) -> Map<String, Any?>): List<Map<String, Any?>> =
    ids.take(20).map { id ->
        try { snapshot(id) }
        catch (error: Exception) {
            mapOf("id" to id, "status" to "error", "error" to "Android could not read this download.", "errorType" to error.javaClass.simpleName)
        }
    }

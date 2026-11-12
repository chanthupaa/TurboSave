package com.turbosave.videodownloader

import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import org.json.JSONObject
import java.nio.ByteBuffer

internal data class PartState(val status: Int, val bytes: Long, val total: Long, val reason: Int = 0)

internal fun combinedParts(video: PartState?, audio: PartState?): Map<String, Any?> {
    if (video == null || audio == null) return mapOf("status" to "failed", "error" to "An Android download record was removed.")
    val parts = listOf(video, audio)
    val status = when {
        parts.any { it.status == DownloadManager.STATUS_FAILED } -> "failed"
        parts.all { it.status == DownloadManager.STATUS_SUCCESSFUL } -> "merging"
        parts.any { it.status == DownloadManager.STATUS_PAUSED } -> "paused"
        parts.any { it.status == DownloadManager.STATUS_RUNNING } -> "downloading"
        else -> "queued"
    }
    return mapOf("status" to status, "bytes" to parts.sumOf { it.bytes.coerceAtLeast(0) },
        "total" to if (parts.any { it.total < 0 }) -1L else parts.sumOf { it.total },
        "error" to when (status) {
            "failed" -> "Android could not complete an adaptive part (code ${parts.first { it.status == DownloadManager.STATUS_FAILED }.reason})."
            "paused" -> "Waiting for a permitted network or Android to resume."
            else -> null
        })
}

/** The primary ID is the public handle. The secondary ID and final URI survive activity recreation. */
internal class AdaptiveTransfers(private val context: Context, private val downloads: DownloadManager) {
    private val prefs = context.getSharedPreferences("adaptive_transfers_v1", Context.MODE_PRIVATE)
    private val resolver = context.contentResolver
    private val lock = Any()

    fun get(id: Long): JSONObject? = synchronized(lock) { read(id) }
    private fun read(id: Long): JSONObject? = prefs.getString(id.toString(), null)?.let { JSONObject(it) }
    private fun save(id: Long, record: JSONObject) {
        check(prefs.edit().putString(id.toString(), record.toString()).commit()) { "Could not save adaptive download state." }
    }

    fun start(primary: Long, name: String) = synchronized(lock) {
        save(primary, JSONObject().put("audio", 0).put("name", name))
    }

    fun add(primary: Long, audio: Long, name: String) = synchronized(lock) {
        save(primary, JSONObject().put("audio", audio).put("name", name))
    }

    fun discard(id: Long) = synchronized(lock) { prefs.edit().remove(id.toString()).commit() }

    fun query(id: Long): Map<String, Any?> = synchronized(lock) {
        val record = read(id) ?: return mapOf("id" to id, "status" to "unknown")
        if (record.optLong("audio") <= 0) return mapOf("id" to id, "status" to "failed", "uri" to null,
            "error" to "The app closed before the audio part was queued. Cancel and retry this download.")
        val final = record.optString("final")
        if (final.isNotEmpty()) {
            try { downloads.remove(id, record.getLong("audio")) } catch (_: Exception) { }
            return mapOf("id" to id, "status" to "completed", "bytes" to record.optLong("bytes", 0),
                "total" to record.optLong("bytes", 0), "uri" to final, "error" to null)
        }
        val video = part(id)
        val audio = part(record.getLong("audio"))
        val state = combinedParts(video, audio)
        if (state["status"] != "merging") return state + ("id" to id) + ("uri" to null)
        return try {
            val uri = merge(id, record)
            val bytes = (video?.total ?: 0) + (audio?.total ?: 0)
            record.put("final", uri.toString()).put("bytes", bytes)
            save(id, record)
            // Only IDs in this record are removed; the finished MediaStore item is retained.
            try { downloads.remove(id, record.getLong("audio")) } catch (_: Exception) { }
            mapOf("id" to id, "status" to "completed", "bytes" to bytes, "total" to bytes, "uri" to uri.toString(), "error" to null)
        } catch (error: Exception) {
            mapOf("id" to id, "status" to "failed", "bytes" to state["bytes"], "total" to state["total"],
                "uri" to null, "error" to "Could not merge the video and audio: ${error.message?.take(150) ?: "unsupported media"}.")
        }
    }

    fun resumePending() {
        val ids = synchronized(lock) { prefs.all.keys.mapNotNull { it.toLongOrNull() } }
        ids.forEach {
            try {
                if (get(it)?.optLong("audio") == 0L) downloads.remove(it)
                else query(it)
            } catch (_: Exception) { /* A later query retries. */ }
        }
    }

    fun cancel(id: Long) = synchronized(lock) {
        val record = read(id) ?: error("This adaptive download was removed.")
        if (record.optLong("audio") > 0) downloads.remove(id, record.getLong("audio")) else downloads.remove(id)
        record.optString("pending").takeIf { it.isNotEmpty() }?.let { resolver.delete(Uri.parse(it), null, null) }
        // Cancel keeps an already published result, matching normal DownloadManager semantics.
        check(prefs.edit().remove(id.toString()).commit()) { "Could not remove adaptive download state." }
    }

    fun finalUri(id: Long): String? = synchronized(lock) { read(id)?.optString("final")?.takeIf { it.isNotEmpty() } }

    private fun part(id: Long): PartState? {
        downloads.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
            if (!cursor.moveToFirst()) return null
            return PartState(cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)),
                cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)),
                cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)),
                cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)))
        }
    }

    private fun merge(id: Long, record: JSONObject): Uri {
        check(Build.VERSION.SDK_INT >= 29) { "Adaptive downloads require Android 10 or newer." }
        record.optString("pending").takeIf { it.isNotEmpty() }?.let {
            resolver.delete(Uri.parse(it), null, null)
            record.remove("pending")
            save(id, record)
        }
        val videoUri = downloads.getUriForDownloadedFile(id) ?: error("Video part is missing")
        val audioUri = downloads.getUriForDownloadedFile(record.getLong("audio")) ?: error("Audio part is missing")
        val video = MediaExtractor()
        val audio = MediaExtractor()
        try {
            video.setDataSource(context, videoUri, null)
            audio.setDataSource(context, audioUri, null)
            val videoTrack = findTrack(video, "video/")
            val audioTrack = findTrack(audio, "audio/")
            check(videoTrack >= 0 && audioTrack >= 0) { "The parts do not contain video and audio streams" }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, record.getString("name"))
                put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/TurboSave")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val output = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: error("Could not create output")
            record.put("pending", output.toString())
            save(id, record)
            try {
                resolver.openFileDescriptor(output, "w")?.use { descriptor ->
                    val muxer = MediaMuxer(descriptor.fileDescriptor, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                    try {
                        val v = muxer.addTrack(video.getTrackFormat(videoTrack))
                        val a = muxer.addTrack(audio.getTrackFormat(audioTrack))
                        muxer.start()
                        copyTrack(video, videoTrack, muxer, v)
                        copyTrack(audio, audioTrack, muxer, a)
                        muxer.stop()
                    } finally { muxer.release() }
                } ?: error("Could not open output")
                val check = MediaExtractor()
                try {
                    check.setDataSource(context, output, null)
                    require(findTrack(check, "video/") >= 0 && findTrack(check, "audio/") >= 0) { "Merged output is missing a stream" }
                } finally { check.release() }
                check(resolver.update(output, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null) == 1) {
                    "Could not publish merged media"
                }
                record.remove("pending")
                return output
            } catch (failure: Exception) {
                resolver.delete(output, null, null)
                record.remove("pending")
                save(id, record)
                throw failure
            }
        } finally { video.release(); audio.release() }
    }

    private fun findTrack(extractor: MediaExtractor, prefix: String): Int =
        (0 until extractor.trackCount).firstOrNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith(prefix) == true } ?: -1

    private fun copyTrack(extractor: MediaExtractor, track: Int, muxer: MediaMuxer, output: Int) {
        extractor.selectTrack(track)
        val format = extractor.getTrackFormat(track)
        val capacity = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE))
            format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE).coerceIn(1024 * 1024, 16 * 1024 * 1024) else 4 * 1024 * 1024
        val buffer = ByteBuffer.allocateDirect(capacity)
        val info = MediaCodec.BufferInfo()
        var count = 0
        var lastTime = -1L
        while (true) {
            buffer.clear()
            val size = extractor.readSampleData(buffer, 0)
            if (size < 0) break
            val time = extractor.sampleTime
            check(time >= lastTime) { "Media samples are out of order" }
            buffer.position(0)
            buffer.limit(size)
            info.set(0, size, time, extractor.sampleFlags)
            muxer.writeSampleData(output, buffer, info)
            lastTime = time
            count++
            extractor.advance()
        }
        check(count > 0) { "A media stream has no samples" }
        extractor.unselectTrack(track)
    }
}

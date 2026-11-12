package com.turbosave.videodownloader

import java.io.InputStream

private const val MEDIA_PREFIX_BYTES = 512

internal fun readMediaPrefix(input: InputStream): ByteArray {
    val bytes = ByteArray(MEDIA_PREFIX_BYTES)
    var count = 0
    while (count < bytes.size) {
        val read = input.read(bytes, count, bytes.size - count)
        if (read < 0) break
        if (read == 0) break
        count += read
    }
    return bytes.copyOf(count)
}

private fun hasMp4Signature(bytes: ByteArray): Boolean {
    val limit = minOf(bytes.size, MEDIA_PREFIX_BYTES)
    var offset = 0
    fun unsigned(start: Int, count: Int): Long {
        var result = 0L
        repeat(count) { result = (result shl 8) or (bytes[start + it].toLong() and 255) }
        return result
    }
    repeat(16) {
        if (limit - offset < 8) return false
        val type = String(bytes, offset + 4, 4, Charsets.US_ASCII)
        val shortSize = unsigned(offset, 4)
        val headerSize = if (shortSize == 1L) 16 else 8
        if (limit - offset < headerSize) return false
        val size = if (shortSize == 1L) {
            // Unsigned sizes beyond Long.MAX_VALUE cannot fit the bounded prefix.
            if (bytes[offset + 8] < 0) return false
            unsigned(offset + 8, 8)
        } else shortSize
        if ((size != 0L && size < headerSize) || (shortSize == 1L && size == 0L)) return false
        if (type in setOf("ftyp", "moov", "mdat")) {
            // A prefix can contain a valid header without the full media box body.
            return limit - offset >= headerSize + 4 && (size == 0L || size >= headerSize + 4)
        }
        if (type !in setOf("free", "skip", "wide")) return false
        // Zero-sized padding extends to EOF; oversized padding hides the next box.
        if (size == 0L || size > limit - offset) return false
        offset += size.toInt()
    }
    return false
}

/** Container signatures reject obvious invalid responses; they do not prove full playback. */
internal fun hasMediaSignature(bytes: ByteArray): Boolean {
    fun ascii(offset: Int, text: String) = bytes.size >= offset + text.length &&
        text.indices.all { bytes[offset + it].toInt() and 255 == text[it].code }
    fun value(index: Int) = bytes[index].toInt() and 255
    if (bytes.size >= 3 && value(0) == 0xff && value(1) == 0xd8 && value(2) == 0xff) return true
    if (bytes.size >= 8 && bytes.take(8).map { it.toInt() and 255 } == listOf(0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a)) return true
    if (bytes.size >= 12 && ascii(0, "RIFF") && ascii(8, "WEBP")) return true
    if (hasMp4Signature(bytes)) return true
    if (bytes.size >= 4 && bytes.take(4).map { it.toInt() and 255 } == listOf(0x1a, 0x45, 0xdf, 0xa3)) return true
    if (bytes.size >= 10 && ascii(0, "ID3") && value(3) in 2..4 && (6..9).all { value(it) < 128 }) return true
    if (bytes.size >= 4 && value(0) == 255 && value(1) and 224 == 224 &&
        value(1) and 24 != 8 && value(1) and 6 != 0 && value(2) shr 4 in 1..14 && value(2) and 12 != 12) return true
    if (bytes.size >= 12 && ascii(0, "RIFF") && ascii(8, "WAVE")) return true
    if (bytes.size >= 48 && ascii(0, "RF64") && (4..7).all { value(it) == 255 } &&
        ascii(8, "WAVE") && ascii(12, "ds64")) return true
    if (ascii(0, "fLaC")) return true
    return bytes.size >= 27 && ascii(0, "OggS") && value(4) == 0
}

internal fun isDownloadableMime(mime: String): Boolean =
    mime.startsWith("video/") || mime.startsWith("audio/") || mime in setOf("image/jpeg", "image/png", "image/webp")

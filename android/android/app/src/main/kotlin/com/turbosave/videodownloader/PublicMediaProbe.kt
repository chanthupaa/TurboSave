package com.turbosave.videodownloader

import java.io.BufferedInputStream
import java.io.InputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URI
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

internal data class ProbeResponse(val status: Int, val headers: Map<String, String>, val prefix: ByteArray)

internal fun readProbeResponse(input: InputStream, budget: NetworkBudget = NetworkBudget()): ProbeResponse {
    val buffered = BufferedInputStream(input)
    val stream = object : InputStream() {
        override fun read(): Int {
            budget.check()
            return buffered.read().also { budget.check() }
        }
        override fun read(bytes: ByteArray, offset: Int, length: Int): Int {
            budget.check()
            return buffered.read(bytes, offset, length).also { budget.check() }
        }
    }
    var headerBytes = 0
    fun line(): String {
        val result = StringBuilder()
        while (true) {
            val byte = stream.read()
            require(byte >= 0) { "Incomplete media response headers." }
            headerBytes++
            require(headerBytes <= 65536 && result.length < 8192) { "Media response headers are too large." }
            if (byte == 10) return result.toString().removeSuffix("\r")
            result.append(byte.toChar())
        }
    }
    var status: Int
    var informational = 0
    val headers = mutableMapOf<String, String>()
    while (true) {
        val first = line().split(' ')
        require(first.size >= 2 && first[0] in setOf("HTTP/1.0", "HTTP/1.1")) { "Invalid media response." }
        status = first[1].toInt()
        headers.clear()
        while (true) {
            val text = line()
            if (text.isEmpty()) break
            require(':' in text) { "Invalid media response header." }
            val name = text.substringBefore(':').lowercase()
            require(name !in headers || name !in setOf("content-length", "content-range", "transfer-encoding", "location")) { "Ambiguous media response headers." }
            headers[name] = text.substringAfter(':').trim()
        }
        if (status !in 100..199 || status == 101) break
        require(++informational <= 16) { "Too many informational media responses." }
    }
    if (status !in setOf(200, 206)) return ProbeResponse(status, headers, ByteArray(0))
    val transfer = headers["transfer-encoding"]?.lowercase()
    require(transfer == null || "content-length" !in headers) { "Ambiguous media response framing." }
    require(transfer == null || transfer == "chunked") { "Unsupported media transfer encoding." }
    val prefix = if (transfer == "chunked") {
        val buffer = java.io.ByteArrayOutputStream()
        while (buffer.size() < 512) {
            val length = line().substringBefore(';').trim().toLong(16)
            require(length >= 0) { "Invalid media chunk." }
            if (length == 0L) break
            val needed = minOf(length, (512 - buffer.size()).toLong()).toInt()
            repeat(needed) { val value = stream.read(); require(value >= 0) { "Incomplete media chunk." }; buffer.write(value) }
            if (length > needed || buffer.size() == 512) break
            require(line().isEmpty()) { "Invalid media chunk delimiter." }
        }
        buffer.toByteArray()
    } else {
        val length = headers["content-length"]?.toLongOrNull()
        if (length != null && length in 0..511) {
            val bytes = ByteArray(length.toInt())
            var count = 0
            while (count < bytes.size) { val n = stream.read(bytes, count, bytes.size - count); require(n > 0) { "Incomplete media response." }; count += n }
            bytes
        } else readMediaPrefix(stream)
    }
    budget.check()
    return ProbeResponse(status, headers, prefix)
}

/** Pins preflight TCP connections to checked addresses and verifies the original TLS hostname. */
internal fun publicMediaProbe(uri: URI, rules: LinkRules, headers: Map<String, String>, budget: NetworkBudget = NetworkBudget()): ProbeResponse {
    val host = uri.host.trimEnd('.')
    var last: Exception? = null
    for (address in rules.publicAddresses(host, budget).sortedBy { it.address.size }.take(4)) {
        val raw = Socket()
        try {
          budget.closeAtDeadline(raw).use {
            raw.connect(InetSocketAddress(address, 443), minOf(8000, budget.remainingMillis().toInt()))
            raw.soTimeout = minOf(12000, budget.remainingMillis().toInt())
            val factory = SSLSocketFactory.getDefault() as SSLSocketFactory
            (factory.createSocket(raw, host, 443, true) as SSLSocket).use { tls ->
                tls.soTimeout = minOf(12000, budget.remainingMillis().toInt())
                val parameters = tls.sslParameters
                parameters.endpointIdentificationAlgorithm = "HTTPS"
                tls.sslParameters = parameters
                tls.startHandshake()
                val path = uri.rawPath.takeUnless { it.isNullOrEmpty() } ?: "/"
                val target = path + (uri.rawQuery?.let { "?$it" } ?: "")
                val request = buildString {
                    append("GET $target HTTP/1.1\r\nHost: $host\r\nConnection: close\r\nRange: bytes=0-511\r\nAccept-Encoding: identity\r\n")
                    if (headers.keys.none { it.equals("user-agent", true) }) append("User-Agent: TurboSave-Android/1.5\r\n")
                    headers.forEach { (name, value) -> append("$name: $value\r\n") }
                    append("\r\n")
                }
                tls.outputStream.write(request.toByteArray(Charsets.UTF_8)); tls.outputStream.flush()
                return readProbeResponse(tls.inputStream, budget)
            }
          }
        } catch (error: Exception) { last = error }
        finally { raw.close() }
        budget.check()
    }
    throw last ?: IllegalStateException("No public media connection was available.")
}

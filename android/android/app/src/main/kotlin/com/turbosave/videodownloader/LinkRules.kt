package com.turbosave.videodownloader

import java.net.InetAddress
import java.net.URI

/** Shared by extraction entry points and system-download validation. No UI-thread networking. */
class LinkRules(
    private val restricted: Boolean,
    private val blocked: Set<String>,
    private val resolve: (String) -> Array<InetAddress> = { InetAddress.getAllByName(it) },
) {
    companion object {
        val extensions = setOf("mp4", "webm", "mov", "mkv", "mp3", "m4a", "ogg", "oga", "wav", "flac", "jpg", "jpeg", "png", "webp")
        private val adultName = Regex("(^|[.\\-])(pornhub|porno|porn|xxx|xvideos|xnxx|redtube|erotic)([.\\-]|$)")
    }
    fun validate(value: String, budget: NetworkBudget = NetworkBudget()): URI {
        budget.check()
        require(value.length <= 8192) { "This link is too long." }
        val uri = URI(value.trim())
        val host = uri.host?.lowercase()?.trimEnd('.') ?: error("Use a public HTTPS link.")
        require(uri.scheme.equals("https", true) && uri.userInfo == null && (uri.port == -1 || uri.port == 443)) { "Use a public HTTPS link without login details." }
        require(host != "localhost" && !host.endsWith(".localhost") && !host.endsWith(".local") && !host.endsWith(".internal") && !host.endsWith(".onion") && !host.contains(':') && !Regex("^[0-9.]+$").matches(host)) { "Private network links are not supported." }
        require(!restricted || (!blocked.any { host == it || host.endsWith(".$it") } && !adultName.containsMatchIn(host))) { "YouTube and identified adult sites are excluded in this edition." }
        publicAddresses(host, budget)
        return uri
    }
    internal fun publicAddresses(host: String, budget: NetworkBudget = NetworkBudget()): Array<InetAddress> {
        val addresses = budget.resolve { resolve(host) }
        require(addresses.size <= 64) { "This source returned too many network addresses." }
        require(addresses.isNotEmpty() && addresses.all { isPublic(it) }) { "Private network destinations are not supported." }
        return addresses
    }
    private fun isPublic(address: InetAddress): Boolean {
        if (address.isAnyLocalAddress || address.isLoopbackAddress || address.isLinkLocalAddress || address.isSiteLocalAddress || address.isMulticastAddress) return false
        val b = address.address.map { it.toInt() and 255 }
        if (b.size == 4) {
            if (b[0] == 0 || b[0] == 127 || b[0] >= 224 || b[0] == 10) return false
            if (b[0] == 100 && b[1] in 64..127 || b[0] == 169 && b[1] == 254 || b[0] == 172 && b[1] in 16..31) return false
            if (b[0] == 192 && b[1] == 168 || b[0] == 192 && b[1] == 0 || b[0] == 198 && b[1] in 18..19 || b[0] == 198 && b[1] == 51 && b[2] == 100 || b[0] == 203 && b[1] == 0 && b[2] == 113) return false
        }
        if (b.size == 16 && ((b[0] and 254) == 252 || b.take(4) == listOf(32, 1, 13, 184))) return false
        return true
    }
}

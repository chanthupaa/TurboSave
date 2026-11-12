package com.turbosave.videodownloader
import java.net.InetAddress
import org.junit.Assert.*
import org.junit.Test

class LinkRulesTest {
    private val publicIp = arrayOf(InetAddress.getByAddress(byteArrayOf(8,8,8,8)))
    private fun rules(restricted: Boolean, privateDns: Boolean = false) = LinkRules(restricted, setOf("youtube.com", "youtu.be", "pornhub.com")) {
        if (privateDns) arrayOf(InetAddress.getByAddress(byteArrayOf(127,0,0,1))) else publicIp
    }
    @Test fun restrictedRejectsAliasesAndSubdomains() {
        for (host in listOf("music.youtube.com", "youtu.be", "www.pornhub.com")) {
            try { rules(true).validate("https://$host/watch"); fail("A restricted host was accepted") } catch (_: IllegalArgumentException) { }
        }
    }
    @Test fun openPolicyAllowsSupportedDomainsWithoutChangingNetworkRules() {
        assertEquals("youtube.com", rules(false).validate("https://youtube.com/watch?v=example").host)
        for (restricted in listOf(true,false)) for (url in listOf("http://example.com/a", "https://user:pass@example.com/a", "https://localhost/a", "https://example.com:8443/a", "https://127.0.0.1/a")) {
            try { rules(restricted).validate(url); fail("An unsafe URL was accepted") } catch (_: IllegalArgumentException) { }
        }
    }
    @Test fun privateDnsAnswersAreRejectedInBothEditions() {
        for (restricted in listOf(true,false)) {
            try { rules(restricted,true).validate("https://example.com/file.mp4"); fail("Private DNS was accepted") } catch (_: IllegalArgumentException) { }
        }
    }
}

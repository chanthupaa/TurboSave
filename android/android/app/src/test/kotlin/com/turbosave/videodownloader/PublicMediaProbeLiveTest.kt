package com.turbosave.videodownloader

import java.net.URI
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test

class PublicMediaProbeLiveTest {
    @Test fun publicBlenderMediaPassesPinnedTlsAndContainerCheck() {
        assumeTrue("Opt-in public network smoke test", System.getenv("TURBOSAVE_LIVE_PROBE") == "1")
        val rules = LinkRules(false, emptySet())
        val uri = rules.validate("https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4")
        val response = publicMediaProbe(uri, rules, emptyMap())
        assertTrue(response.status in setOf(200, 206))
        assertTrue(response.headers["content-type"].orEmpty().startsWith("video/"))
        assertTrue(hasMediaSignature(response.prefix))
        assertEquals(512, response.prefix.size)
    }
}

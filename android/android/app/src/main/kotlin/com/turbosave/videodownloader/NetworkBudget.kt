package com.turbosave.videodownloader

import java.io.Closeable
import java.net.Socket
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** One deadline is shared by queued work, DNS, redirects and preflight I/O. */
class NetworkBudget(
    timeoutMillis: Long = 65_000,
    private val clock: () -> Long = System::nanoTime,
) {
    private val deadline = clock() + TimeUnit.MILLISECONDS.toNanos(timeoutMillis)

    fun remainingMillis(): Long {
        val remaining = deadline - clock()
        check(remaining > 0 && !Thread.currentThread().isInterrupted) {
            "This source took too long to check. Try another link."
        }
        return maxOf(1, (remaining + 999_999) / 1_000_000)
    }

    fun check() { remainingMillis() }

    internal fun <T> resolve(lookup: () -> T): T {
        check()
        val future = try { dns.submit(Callable { check(); lookup() }) }
        catch (_: RejectedExecutionException) {
            throw IllegalStateException("Network lookup is busy. Try again shortly.")
        }
        try {
            val value = future.get(remainingMillis(), TimeUnit.MILLISECONDS)
            check()
            return value
        } catch (_: TimeoutException) {
            throw IllegalStateException("This source took too long to check. Try another link.")
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            throw IllegalStateException("This source check was interrupted.", error)
        } catch (error: ExecutionException) {
            throw error.cause ?: error
        } finally {
            if (!future.isDone) future.cancel(true)
        }
    }

    internal fun closeAtDeadline(socket: Socket): Closeable {
        val alarm = watchdog.schedule({
            try { socket.close() } catch (_: Exception) { }
        }, remainingMillis(), TimeUnit.MILLISECONDS)
        return Closeable { alarm.cancel(false) }
    }

    companion object {
        // Native DNS cannot always be interrupted; never allow timed-out lookups to spawn unlimited workers.
        private val dns = ThreadPoolExecutor(2, 2, 20, TimeUnit.SECONDS, SynchronousQueue<Runnable>(), {
            Thread(it, "TurboSave-DNS").apply { isDaemon = true }
        }).apply { allowCoreThreadTimeOut(true) }
        private val watchdog = ScheduledThreadPoolExecutor(1, {
            Thread(it, "TurboSave-network-deadline").apply { isDaemon = true }
        }).apply {
            removeOnCancelPolicy = true
            setKeepAliveTime(20, TimeUnit.SECONDS)
            allowCoreThreadTimeOut(true)
        }
    }
}

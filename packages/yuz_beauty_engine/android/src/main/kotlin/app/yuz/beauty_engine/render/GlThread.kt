package app.yuz.beauty_engine.render

import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/** Dedicated thread that owns the EGL context. Every GL call goes through it. */
class GlThread(name: String) {
    private val thread = HandlerThread(name, Process.THREAD_PRIORITY_DISPLAY).apply { start() }
    val handler = Handler(thread.looper)

    val isCurrent: Boolean get() = Thread.currentThread() === thread

    fun post(block: () -> Unit) {
        handler.post(block)
    }

    suspend fun <T> run(block: () -> T): T = suspendCancellableCoroutine { continuation ->
        val posted = handler.post {
            try {
                continuation.resume(block())
            } catch (error: Throwable) {
                continuation.resumeWithException(error)
            }
        }
        if (!posted) continuation.resumeWithException(IllegalStateException("GL thread has quit"))
    }

    /**
     * Runs [block] synchronously and waits up to [timeoutMillis]. Used only
     * where the caller must not return before GL work completes (Flutter's
     * surface cleanup callback).
     */
    fun runBlocking(timeoutMillis: Long, block: () -> Unit): Boolean {
        if (isCurrent) {
            block()
            return true
        }
        val latch = CountDownLatch(1)
        val posted = handler.post {
            try {
                block()
            } finally {
                latch.countDown()
            }
        }
        return posted && latch.await(timeoutMillis, TimeUnit.MILLISECONDS)
    }

    fun quit() {
        thread.quitSafely()
    }
}

package app.yuz.beauty_engine.video

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

class RecordingTimelineTest {
    private val start = 10_000_000_000L

    @Test
    fun `monotonic camera timestamps map directly`() {
        val timeline = RecordingTimeline(start)
        assertEquals(0L, timeline.videoPresentationUs(start, start + 5_000_000))
        assertEquals(33_333L, timeline.videoPresentationUs(start + 33_333_333, start + 40_000_000))
    }

    @Test
    fun `boot-time camera timestamps are shifted into the monotonic clock`() {
        val timeline = RecordingTimeline(start)
        val bootOffset = 3_600_000_000_000L
        // Frame captured 10 ms ago in a clock that runs one hour ahead.
        val first = timeline.videoPresentationUs(start + 20_000_000 + bootOffset, start + 20_000_000)
        assertEquals(20_000L, first)
        assertEquals(53_333L, timeline.videoPresentationUs(start + 53_333_333 + bootOffset, start + 60_000_000))
    }

    @Test
    fun `frames before the start or out of order are dropped`() {
        val timeline = RecordingTimeline(start)
        assertNull(timeline.videoPresentationUs(start - 1_000_000, start))
        assertEquals(50_000L, timeline.videoPresentationUs(start + 50_000_000, start + 50_000_000))
        assertNull(timeline.videoPresentationUs(start + 50_000_000, start + 60_000_000))
        assertNull(timeline.videoPresentationUs(start + 40_000_000, start + 60_000_000))
    }

    @Test
    fun `audio is never dropped after the start and always increases`() {
        val timeline = RecordingTimeline(start)
        assertNull(timeline.audioPresentationUs(start - 1))
        assertEquals(1_000L, timeline.audioPresentationUs(start + 1_000_000))
        assertEquals(1_001L, timeline.audioPresentationUs(start + 1_000_000))
        assertEquals(1_002L, timeline.audioPresentationUs(start + 500_000))
        assertEquals(1_002L, timeline.durationUs)
    }

    @Test
    fun `audio clock counts samples from the first chunk`() {
        val clock = AudioSampleClock(44_100)
        val first = clock.chunkStartNanos(frames = 2_048, readCompletedNanos = 1_000_000_000L)
        val second = clock.chunkStartNanos(frames = 2_048, readCompletedNanos = 9_999_999_999L)
        // The first chunk ended when it was read; the second starts right after it
        // no matter how late the read returned.
        assertEquals(1_000_000_000L - 2_048L * 1_000_000_000L / 44_100, first)
        assertEquals(1_000_000_000L, second)
    }

    @Test
    fun `encoder size is macroblock aligned and bitrate bounded`() {
        val hd = VideoEncoderSpec.forOutput(1080, 1920)
        assertEquals(1072, hd.width)
        assertEquals(1920, hd.height)
        assertTrue(hd.bitrate in 2_000_000..20_000_000)
        assertEquals(30, hd.frameRate)

        assertEquals(2_000_000, VideoEncoderSpec.forOutput(320, 240).bitrate)
        assertEquals(20_000_000, VideoEncoderSpec.forOutput(1080, 1920, requestedBitrate = 90_000_000).bitrate)
        assertFailsWith<IllegalArgumentException> { VideoEncoderSpec.forOutput(8, 8) }
    }

    @Test
    fun `exact frame size is kept when the encoder supports it`() {
        val spec = VideoEncoderSpec.forOutput(1080, 1921, isSizeSupported = { w, h -> w == 1080 && h == 1920 })
        assertEquals(1080, spec.width)
        assertEquals(1920, spec.height)
    }
}

package app.yuz.beauty_engine.video.edit

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class VideoEditPlanTest {
    private fun clip(
        durationUs: Long = 10_000_000,
        start: Long = 0,
        end: Long = durationUs,
        speed: Double = 1.0,
        width: Int = 1080,
        height: Int = 1920,
        audio: Boolean = true,
    ) = ClipInput("/c.mp4", durationUs, start, end, speed, width, height, audio)

    @Test
    fun `clips are laid end to end with trims and speed`() {
        val plan = VideoEditPlanner.plan(
            listOf(clip(start = 1_000_000, end = 4_000_000), clip(start = 0, end = 2_000_000, speed = 2.0)),
            maxLongEdge = 1920,
        )
        assertEquals(2, plan.segments.size)
        assertEquals(0L, plan.segments[0].outputStartUs)
        assertEquals(3_000_000L, plan.segments[0].outputDurationUs)
        assertEquals(3_000_000L, plan.segments[1].outputStartUs)
        assertEquals(1_000_000L, plan.segments[1].outputDurationUs)
        assertEquals(4_000_000L, plan.durationUs)
        assertEquals(1_000_000L + 3_000_000L, plan.segments[1].outputTimeUs(2_000_000))
        assertEquals(500_000L, plan.segments[0].outputTimeUs(1_500_000))
    }

    @Test
    fun `sound is only kept at normal speed`() {
        val plan = VideoEditPlanner.plan(listOf(clip(), clip(speed = 0.5), clip(audio = false)), 1920)
        assertTrue(plan.segments[0].keepsSound)
        assertFalse(plan.segments[1].keepsSound)
        assertFalse(plan.segments[2].keepsSound)
    }

    @Test
    fun `trims are clamped to the clip and too short ranges are rejected`() {
        val plan = VideoEditPlanner.plan(listOf(clip(start = -5, end = 99_000_000)), 1920)
        assertEquals(0L, plan.segments[0].startUs)
        assertEquals(10_000_000L, plan.segments[0].endUs)
        assertFailsWith<IllegalArgumentException> { VideoEditPlanner.plan(listOf(clip(start = 0, end = 50_000)), 1920) }
        assertFailsWith<IllegalArgumentException> { VideoEditPlanner.plan(listOf(clip(speed = 8.0)), 1920) }
        assertFailsWith<IllegalArgumentException> { VideoEditPlanner.plan(emptyList(), 1920) }
    }

    @Test
    fun `output follows the first clip aspect, even sized and never upscaled`() {
        assertEquals(1080 to 1920, VideoEditPlanner.outputSize(2160, 3840, 1920))
        assertEquals(1280 to 720, VideoEditPlanner.outputSize(1280, 720, 1920))
        assertEquals(1920 to 1080, VideoEditPlanner.outputSize(1999, 1125, 1920))
        val odd = VideoEditPlanner.outputSize(1001, 777, 1920)
        assertEquals(1000 to 776, odd)
    }

    @Test
    fun `letterbox centers the source aspect inside the frame`() {
        assertEquals(Viewport(0, 657, 1080, 606), Letterbox.fit(1920, 1078, 1080, 1920))
        assertEquals(Viewport(0, 0, 1080, 1920), Letterbox.fit(1080, 1920, 1080, 1920))
        val pillar = Letterbox.fit(1080, 1920, 1920, 1080)
        assertEquals(1080, pillar.height)
        assertEquals((1920 - pillar.width) / 2, pillar.x)
    }

    @Test
    fun `overlay windows are half-open`() {
        val window = OverlayWindow("/o.png", 1_000, 2_000)
        assertFalse(window.isVisibleAt(999))
        assertTrue(window.isVisibleAt(1_000))
        assertFalse(window.isVisibleAt(2_000))
    }
}

class PcmProcessingTest {
    private fun sine(frames: Int, rate: Int, channels: Int, frequency: Double, startFrame: Int = 0) =
        ShortArray(frames * channels) { i ->
            val frame = startFrame + i / channels
            (sin(2 * PI * frequency * frame / rate) * 16_000).toInt().toShort()
        }

    @Test
    fun `same rate stereo passes through`() {
        val resampler = StereoResampler(44_100, 2, 44_100)
        val input = shortArrayOf(16384, -16384, 8192, -8192, 0, 0)
        val out = resampler.process(input)
        assertEquals(4, out.size, "the last frame waits for its successor")
        assertEquals(0.5f, out[0], 1e-4f)
        assertEquals(-0.5f, out[1], 1e-4f)
        assertEquals(0.25f, out[2], 1e-4f)
    }

    @Test
    fun `mono is duplicated to both channels`() {
        val out = StereoResampler(44_100, 1, 44_100).process(shortArrayOf(16384, 16384, 16384))
        assertEquals(out[0], out[1])
    }

    @Test
    fun `48k to 44_1k keeps duration and pitch across chunk boundaries`() {
        val resampler = StereoResampler(48_000, 2, 44_100)
        val chunks = (0 until 10).map { sine(4_800, 48_000, 2, 440.0, startFrame = it * 4_800) }
        val out = chunks.map { resampler.process(it) }.fold(FloatArray(0)) { acc, part -> acc + part }
        val frames = out.size / 2
        assertTrue(abs(frames - 44_100) <= 2, "one second in, one second out (got $frames frames)")
        // Compare against the analytic sine at the output rate: chunk joins must not glitch.
        var maxError = 0.0
        for (frame in 0 until frames) {
            val expected = sin(2 * PI * 440.0 * frame / 44_100) * 16_000 / 32_768
            maxError = maxOf(maxError, abs(out[frame * 2] - expected))
        }
        assertTrue(maxError < 0.01, "max interpolation error $maxError")
    }

    @Test
    fun `mixer applies gains, fade out and clipping`() {
        val original = floatArrayOf(0.5f, 0.5f, 0.5f, 0.5f)
        val music = floatArrayOf(0.8f, 0.8f, 0.8f, 0.8f)
        val loud = PcmMixer.mix(original, 1f, music, 1f, frames = 2, startFrame = 0, totalFrames = 100, fadeOutFrames = 0)
        assertEquals(32_767, loud[0].toInt(), "clamped")
        val faded = PcmMixer.mix(null, 0f, music, 1f, frames = 2, startFrame = 98, totalFrames = 100, fadeOutFrames = 4)
        assertEquals((0.8f * 0.5f * 32_767).toInt(), faded[0].toInt())
        assertEquals((0.8f * 0.25f * 32_767).toInt(), faded[2].toInt())
        val silent = PcmMixer.mix(original, 0f, null, 0f, frames = 2, startFrame = 0, totalFrames = 2, fadeOutFrames = 0)
        assertTrue(silent.all { it.toInt() == 0 })
    }

    @Test
    fun `fifo returns exact frame counts and pads with silence`() {
        val fifo = StereoFifo()
        fifo.append(FloatArray(10_000) { it.toFloat() })
        assertEquals(5_000, fifo.frames)
        val first = fifo.take(2)
        assertEquals(listOf(0f, 1f, 2f, 3f), first.toList())
        fifo.skip(4_997)
        val tail = fifo.take(3)
        assertEquals(listOf(9_998f, 9_999f, 0f, 0f, 0f, 0f), tail.toList())
        assertEquals(0, fifo.frames)
        fifo.append(FloatArray(20_000))
        assertEquals(10_000, fifo.frames)
    }
}

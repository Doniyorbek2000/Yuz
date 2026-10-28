package app.yuz.beauty_engine.still

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class StillImageGeometryTest {
    @Test
    fun exifOrientationsMapToFlipThenRotate() {
        assertEquals(ExifTransform(0, false), ExifTransform.forOrientation(1))
        assertEquals(ExifTransform(0, true), ExifTransform.forOrientation(2))
        assertEquals(ExifTransform(180, false), ExifTransform.forOrientation(3))
        assertEquals(ExifTransform(180, true), ExifTransform.forOrientation(4))
        assertEquals(ExifTransform(90, true), ExifTransform.forOrientation(5))
        assertEquals(ExifTransform(90, false), ExifTransform.forOrientation(6))
        assertEquals(ExifTransform(270, true), ExifTransform.forOrientation(7))
        assertEquals(ExifTransform(270, false), ExifTransform.forOrientation(8))
        assertEquals(ExifTransform(0, false), ExifTransform.forOrientation(0), "undefined = normal")
    }

    @Test
    fun portraitPhoneShotStoredLandscapeIsUprightPortrait() {
        // Typical phone JPEG: stored 4032x3024 with orientation 6.
        val plan = StillImageGeometry.plan(4032, 3024, ExifTransform.forOrientation(6), 0, 8192)
        assertEquals(3024, plan.uprightWidth)
        assertEquals(4032, plan.uprightHeight)
        assertEquals(3024, plan.targetWidth)
        assertEquals(4032, plan.targetHeight)
        assertEquals(1, plan.inSampleSize)
    }

    @Test
    fun previewSizeUsesSubsampledDecode() {
        val plan = StillImageGeometry.plan(4032, 3024, ExifTransform.forOrientation(1), 1600, 8192)
        assertEquals(1600, plan.targetWidth)
        assertEquals(1200, plan.targetHeight)
        assertEquals(2, plan.inSampleSize)
        assertTrue(4032 / plan.inSampleSize >= plan.targetWidth)
    }

    @Test
    fun outputIsCappedAtGpuTextureSize() {
        val plan = StillImageGeometry.plan(12000, 3000, ExifTransform.forOrientation(1), 0, 4096)
        assertEquals(4096, plan.targetWidth)
        assertEquals(1024, plan.targetHeight)
    }

    @Test
    fun outputIsCappedAtMaxPixels() {
        val plan = StillImageGeometry.plan(8000, 6000, ExifTransform.forOrientation(1), 0, 16384)
        assertTrue(plan.targetWidth.toLong() * plan.targetHeight <= StillImageGeometry.MAX_PIXELS + 10_000)
        assertEquals(4f / 3f, plan.targetWidth.toFloat() / plan.targetHeight, 0.01f)
    }

    @Test
    fun neverUpscales() {
        val plan = StillImageGeometry.plan(800, 600, ExifTransform.forOrientation(1), 1600, 8192)
        assertEquals(800, plan.targetWidth)
        assertEquals(600, plan.targetHeight)
    }

    @Test
    fun rejectsEmptyImages() {
        assertFailsWith<IllegalArgumentException> {
            StillImageGeometry.plan(0, 10, ExifTransform.forOrientation(1), 0, 4096)
        }
    }
}

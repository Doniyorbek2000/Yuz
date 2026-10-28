package app.yuz.beauty_engine.face

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class FaceWarpBuilderTest {
    /**
     * Synthetic frontal face: every landmark at the centre except the ones the
     * builder reads, which get anatomically plausible positions (top-left space).
     */
    private fun face(scale: Float = 1f): List<NormalizedPoint> {
        val points = MutableList(FaceMaskGeometry.MESH_LANDMARK_COUNT) { NormalizedPoint(0.5f, 0.5f) }
        fun set(index: Int, x: Float, y: Float) {
            points[index] = NormalizedPoint(0.5f + (x - 0.5f) * scale, 0.5f + (y - 0.5f) * scale)
        }
        set(234, 0.30f, 0.50f)
        set(454, 0.70f, 0.50f)
        set(10, 0.50f, 0.25f)
        set(152, 0.50f, 0.78f)
        set(4, 0.50f, 0.55f)
        set(129, 0.46f, 0.56f)
        set(358, 0.54f, 0.56f)
        set(13, 0.50f, 0.64f)
        set(14, 0.50f, 0.66f)
        set(61, 0.44f, 0.65f)
        set(291, 0.56f, 0.65f)
        set(33, 0.36f, 0.45f)
        set(133, 0.45f, 0.45f)
        set(263, 0.64f, 0.45f)
        set(362, 0.55f, 0.45f)
        for (i in listOf(93, 132, 58)) set(i, 0.32f, 0.60f)
        for (i in listOf(323, 361, 288)) set(i, 0.68f, 0.60f)
        set(172, 0.36f, 0.70f)
        set(397, 0.64f, 0.70f)
        for (i in FaceMaskGeometry.LEFT_EYE) set(i, 0.405f, 0.45f)
        for (i in FaceMaskGeometry.RIGHT_EYE) set(i, 0.595f, 0.45f)
        return points
    }

    @Test
    fun identitySettingsProduceNoWarps() {
        assertTrue(FaceWarpBuilder.build(face(), ReshapeSettings(), aspect = 0.5625f).isEmpty())
    }

    @Test
    fun maximumSettingsStayWithinShaderLimit() {
        val all = ReshapeSettings(1f, 1f, 1f, 1f, 1f, 1f, 1f)
        val warps = FaceWarpBuilder.build(face(), all, aspect = 0.5625f)
        assertEquals(15, warps.size)
        assertTrue(warps.size <= FaceWarpBuilder.MAX_WARPS)
    }

    @Test
    fun faceSlimPushesContourTowardsTheCentre() {
        val warps = FaceWarpBuilder.build(face(), ReshapeSettings(faceSlim = 1f), aspect = 0.5625f)
        assertEquals(6, warps.size)
        for (warp in warps) {
            assertEquals(FaceWarp.Kind.TRANSLATE, warp.kind)
            val towardsCentre = if (warp.centerX < 0.5f) warp.offsetX > 0f else warp.offsetX < 0f
            assertTrue(towardsCentre, "warp at ${warp.centerX} moves ${warp.offsetX}")
        }
    }

    @Test
    fun eyeEnlargeBulgesAtEachEyeCentre() {
        val warps = FaceWarpBuilder.build(face(), ReshapeSettings(eyeEnlarge = 0.5f), aspect = 0.5625f)
        assertEquals(2, warps.size)
        assertEquals(0.405f, warps[0].centerX, 1e-4f)
        assertEquals(0.595f, warps[1].centerX, 1e-4f)
        assertTrue(warps.all { it.kind == FaceWarp.Kind.BULGE && abs(it.strength - 0.11f) < 1e-4f })
    }

    @Test
    fun chinMovesUpAndForeheadMovesDown() {
        val chin = FaceWarpBuilder.build(face(), ReshapeSettings(chin = 1f), aspect = 1f).single()
        val forehead = FaceWarpBuilder.build(face(), ReshapeSettings(forehead = 1f), aspect = 1f).single()
        assertTrue(chin.offsetY < 0f)
        assertTrue(forehead.offsetY > 0f)
    }

    @Test
    fun warpsScaleWithFaceSize() {
        val near = FaceWarpBuilder.build(face(1f), ReshapeSettings(faceSlim = 1f), aspect = 1f).first()
        val far = FaceWarpBuilder.build(face(0.5f), ReshapeSettings(faceSlim = 1f), aspect = 1f).first()
        assertEquals(near.radius / 2f, far.radius, 1e-4f)
        assertEquals(near.offsetX / 2f, far.offsetX, 1e-4f)
    }

    @Test
    fun degenerateFaceProducesNoWarps() {
        val flat = List(FaceMaskGeometry.MESH_LANDMARK_COUNT) { NormalizedPoint(0.5f, 0.5f) }
        assertTrue(FaceWarpBuilder.build(flat, ReshapeSettings(faceSlim = 1f), aspect = 1f).isEmpty())
    }
}

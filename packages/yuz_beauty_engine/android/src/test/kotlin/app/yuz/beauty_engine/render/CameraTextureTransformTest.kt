package app.yuz.beauty_engine.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class CameraTextureTransformTest {
    private fun assertMaps(matrix: FloatArray, from: Pair<Float, Float>, to: Pair<Float, Float>) {
        val (u, v) = CameraTextureTransform.apply(matrix, from.first, from.second)
        assertEquals(to.first, u, 1e-5f, "u for $from")
        assertEquals(to.second, v, 1e-5f, "v for $from")
    }

    @Test
    fun identityWithoutRotationOrMirror() {
        val m = CameraTextureTransform.displayToBuffer(0, false)
        assertMaps(m, 0f to 0f, 0f to 0f)
        assertMaps(m, 1f to 1f, 1f to 1f)
    }

    @Test
    fun rotation90SamplesBufferAtOneMinusVAndU() {
        // Upright display point (u, v) samples buffer at (1 - v, u).
        val m = CameraTextureTransform.displayToBuffer(90, false)
        assertMaps(m, 0f to 0f, 1f to 0f)
        assertMaps(m, 1f to 0f, 1f to 1f)
        assertMaps(m, 0f to 1f, 0f to 0f)
        assertMaps(m, 0.5f to 0.5f, 0.5f to 0.5f)
    }

    @Test
    fun rotation270IsInverseOf90() {
        val m90 = CameraTextureTransform.displayToBuffer(90, false)
        val m270 = CameraTextureTransform.displayToBuffer(270, false)
        val product = CameraTextureTransform.multiply(m90, m270)
        assertMaps(product, 0.2f to 0.7f, 0.2f to 0.7f)
    }

    @Test
    fun mirrorFlipsHorizontally() {
        val m = CameraTextureTransform.displayToBuffer(0, true)
        assertMaps(m, 0f to 0.3f, 1f to 0.3f)
        assertMaps(m, 0.25f to 0.6f, 0.75f to 0.6f)
    }

    @Test
    fun frontCameraRotationAndMirrorCompose() {
        // Typical front sensor: 270° and mirrored.
        val m = CameraTextureTransform.displayToBuffer(270, true)
        // Mirror first: (0,0) -> (1,0); then 270° maps (u,v) -> (v, 1-u): (1,0) -> (0,0).
        assertMaps(m, 0f to 0f, 0f to 0f)
        assertMaps(m, 1f to 0f, 0f to 1f)
    }

    @Test
    fun uprightSizeSwapsForQuarterTurns() {
        assertEquals(1080 to 1920, CameraTextureTransform.uprightSize(1920, 1080, 90))
        assertEquals(1080 to 1920, CameraTextureTransform.uprightSize(1920, 1080, 270))
        assertEquals(1920 to 1080, CameraTextureTransform.uprightSize(1920, 1080, 180))
    }

    @Test
    fun rejectsNonQuarterRotation() {
        assertFailsWith<IllegalArgumentException> { CameraTextureTransform.displayToBuffer(45, false) }
    }
}

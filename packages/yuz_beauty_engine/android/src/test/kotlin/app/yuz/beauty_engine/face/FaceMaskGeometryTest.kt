package app.yuz.beauty_engine.face

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class FaceMaskGeometryTest {
    private fun mesh(transform: (Int) -> NormalizedPoint = { NormalizedPoint(0.5f, 0.5f) }) =
        List(FaceMaskGeometry.MESH_LANDMARK_COUNT, transform)

    @Test
    fun packedLayoutMatchesShader() {
        val uniforms = FaceMaskGeometry.build(mesh(), aspect = 0.5625f, flipVertical = true)
        // face_mask.frag: 128 points packed into uPoints[64] (vec4 = 2 points).
        assertEquals(FaceMaskGeometry.PACKED_POINTS * 2, uniforms.packedPoints.size)
        assertEquals(256, uniforms.packedPoints.size)
        for (box in listOf(
            uniforms.leftEyeBox, uniforms.rightEyeBox, uniforms.mouthBox,
            uniforms.leftCheek, uniforms.rightCheek, uniforms.faceBounds,
        )) {
            assertEquals(4, box.size)
        }
    }

    @Test
    fun ringSizesSumToPackedPoints() {
        val total = listOf(
            FaceMaskGeometry.FACE_OVAL, FaceMaskGeometry.LEFT_EYE, FaceMaskGeometry.RIGHT_EYE,
            FaceMaskGeometry.LEFT_BROW, FaceMaskGeometry.RIGHT_BROW, FaceMaskGeometry.LIPS_OUTER,
            FaceMaskGeometry.MOUTH_INNER,
        ).sumOf { it.size }
        assertEquals(FaceMaskGeometry.PACKED_POINTS, total)
    }

    @Test
    fun indicesAreValidAndUniquePerRing() {
        for (ring in listOf(
            FaceMaskGeometry.FACE_OVAL, FaceMaskGeometry.LEFT_EYE, FaceMaskGeometry.RIGHT_EYE,
            FaceMaskGeometry.LEFT_BROW, FaceMaskGeometry.RIGHT_BROW, FaceMaskGeometry.LIPS_OUTER,
            FaceMaskGeometry.MOUTH_INNER,
        )) {
            assertEquals(ring.size, ring.distinct().size)
            assertTrue(ring.all { it in 0 until FaceMaskGeometry.MESH_LANDMARK_COUNT })
        }
    }

    @Test
    fun flipsVerticalAxisForOpenGl() {
        val landmarks = mesh { NormalizedPoint(0.4f, 0.2f) }
        val gl = FaceMaskGeometry.build(landmarks, aspect = 1f, flipVertical = true)
        val metal = FaceMaskGeometry.build(landmarks, aspect = 1f, flipVertical = false)
        assertEquals(0.8f, gl.leftEyeBox[1], 1e-5f)
        assertEquals(0.2f, metal.leftEyeBox[1], 1e-5f)
        assertEquals(0.8f, gl.packedPoints[1], 1e-5f)
        assertTrue(gl.faceBounds[1] <= gl.faceBounds[3])
    }

    @Test
    fun cheekEllipseIsRoundInPixels() {
        // Face 0.4 wide; portrait frame (aspect 9:16): ry_uv = rx_uv * aspect * 0.10 / 0.13.
        val landmarks = mesh { index ->
            NormalizedPoint(if (index % 2 == 0) 0.3f else 0.7f, if (index % 3 == 0) 0.3f else 0.7f)
        }
        val uniforms = FaceMaskGeometry.build(landmarks, aspect = 0.5625f, flipVertical = false)
        assertEquals(0.4f * 0.13f, uniforms.leftCheek[2], 1e-5f)
        assertEquals(0.4f * 0.10f * 0.5625f, uniforms.leftCheek[3], 1e-5f)
    }

    @Test
    fun rejectsIncompleteMesh() {
        assertFailsWith<IllegalArgumentException> {
            FaceMaskGeometry.build(List(10) { NormalizedPoint(0f, 0f) }, aspect = 1f, flipVertical = true)
        }
    }
}

package app.yuz.beauty_engine.face

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class FaceMaskGeometryTest {
    private val flatMesh = List(FaceMaskGeometry.MESH_LANDMARK_COUNT) { NormalizedPoint(0.5f, 0.5f) }

    @Test
    fun polygonSizesMatchShaderUniformArrays() {
        val polygons = FaceMaskGeometry.build(flatMesh)
        // face_mask.frag: kOvalPoints 36, kEyePoints 16, kBrowPoints 10, kLipPoints 20 (x2 floats).
        assertEquals(72, polygons.faceOval.size)
        assertEquals(32, polygons.leftEye.size)
        assertEquals(32, polygons.rightEye.size)
        assertEquals(20, polygons.leftBrow.size)
        assertEquals(20, polygons.rightBrow.size)
        assertEquals(40, polygons.lips.size)
    }

    @Test
    fun indicesAreValidAndUniquePerRing() {
        for (ring in listOf(
            FaceMaskGeometry.FACE_OVAL,
            FaceMaskGeometry.LEFT_EYE,
            FaceMaskGeometry.RIGHT_EYE,
            FaceMaskGeometry.LEFT_BROW,
            FaceMaskGeometry.RIGHT_BROW,
            FaceMaskGeometry.LIPS_OUTER,
        )) {
            assertEquals(ring.size, ring.distinct().size)
            assertTrue(ring.all { it in 0 until FaceMaskGeometry.MESH_LANDMARK_COUNT })
        }
    }

    @Test
    fun ringFlipsVerticalAxisAndScalesAboutCentroid() {
        val mesh = flatMesh.toMutableList()
        mesh[0] = NormalizedPoint(0.4f, 0.2f)
        mesh[1] = NormalizedPoint(0.6f, 0.2f)
        mesh[2] = NormalizedPoint(0.5f, 0.4f)
        val ring = FaceMaskGeometry.ring(mesh, intArrayOf(0, 1, 2), scale = 2f)
        // Centroid (0.5, 0.2667); point 0 moves to (0.3, 0.1333) → v = 0.8667.
        assertEquals(0.3f, ring[0], 1e-4f)
        assertEquals(1f - 0.13333f, ring[1], 1e-4f)
    }

    @Test
    fun rejectsIncompleteMesh() {
        assertFailsWith<IllegalArgumentException> {
            FaceMaskGeometry.build(List(10) { NormalizedPoint(0f, 0f) })
        }
    }
}

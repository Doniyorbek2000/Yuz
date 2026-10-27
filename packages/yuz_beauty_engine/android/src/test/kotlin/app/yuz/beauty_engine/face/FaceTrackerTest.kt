package app.yuz.beauty_engine.face

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class FaceTrackerTest {
    private fun face(centerX: Float, centerY: Float, halfSize: Float): DetectedFace {
        // A synthetic 468-point mesh spread on a circle around the centre.
        val points = List(FaceMaskGeometry.MESH_LANDMARK_COUNT) { index ->
            val angle = index * (2.0 * Math.PI / FaceMaskGeometry.MESH_LANDMARK_COUNT)
            NormalizedPoint(
                (centerX + halfSize * kotlin.math.cos(angle)).toFloat(),
                (centerY + halfSize * kotlin.math.sin(angle)).toFloat(),
            )
        }
        return DetectedFace(points)
    }

    @Test
    fun noFacesProducesEmptySnapshot() {
        val tracker = FaceTracker(maxFaces = 2, policy = FaceSelectionPolicy.PRIMARY_FACE)
        val snapshot = tracker.update(emptyList(), 1L)
        assertEquals(0, snapshot.detectedFaceCount)
        assertTrue(snapshot.beautifiedFaces.isEmpty())
    }

    @Test
    fun primaryPolicySelectsLargestFace() {
        val tracker = FaceTracker(maxFaces = 4, policy = FaceSelectionPolicy.PRIMARY_FACE)
        val snapshot = tracker.update(listOf(face(0.3f, 0.5f, 0.1f), face(0.7f, 0.5f, 0.2f)), 1L)
        assertEquals(2, snapshot.detectedFaceCount)
        assertEquals(1, snapshot.beautifiedFaces.size)
        assertEquals(0.7f, snapshot.beautifiedFaces.single().bounds.centerX, 0.01f)
    }

    @Test
    fun primaryFaceHasHysteresis() {
        val tracker = FaceTracker(maxFaces = 4, policy = FaceSelectionPolicy.PRIMARY_FACE)
        val first = tracker.update(listOf(face(0.3f, 0.5f, 0.20f), face(0.7f, 0.5f, 0.15f)), 1L)
        val primaryId = first.beautifiedFaces.single().trackId
        // The other face grows slightly larger, but not by the switch ratio.
        val second = tracker.update(listOf(face(0.3f, 0.5f, 0.20f), face(0.7f, 0.5f, 0.21f)), 2L)
        assertEquals(primaryId, second.beautifiedFaces.single().trackId)
        // Now it is clearly larger (area ratio > 1.3): switch.
        val third = tracker.update(listOf(face(0.3f, 0.5f, 0.20f), face(0.7f, 0.5f, 0.26f)), 3L)
        assertNotEquals(primaryId, third.beautifiedFaces.single().trackId)
    }

    @Test
    fun allFacesPolicyRespectsMaxFaces() {
        val tracker = FaceTracker(maxFaces = 2, policy = FaceSelectionPolicy.ALL_FACES)
        val snapshot = tracker.update(
            listOf(face(0.2f, 0.5f, 0.05f), face(0.5f, 0.5f, 0.1f), face(0.8f, 0.5f, 0.08f)),
            1L,
        )
        assertEquals(3, snapshot.detectedFaceCount)
        assertEquals(2, snapshot.beautifiedFaces.size)
    }

    @Test
    fun trackIdentityIsStableWhileFaceMovesSlightly() {
        val tracker = FaceTracker(maxFaces = 1, policy = FaceSelectionPolicy.PRIMARY_FACE)
        val a = tracker.update(listOf(face(0.5f, 0.5f, 0.2f)), 1L).beautifiedFaces.single().trackId
        val b = tracker.update(listOf(face(0.52f, 0.5f, 0.2f)), 2L).beautifiedFaces.single().trackId
        assertEquals(a, b)
    }

    @Test
    fun faceLeavingAndReturningStartsNewTrack() {
        val tracker = FaceTracker(maxFaces = 1, policy = FaceSelectionPolicy.PRIMARY_FACE)
        val a = tracker.update(listOf(face(0.5f, 0.5f, 0.2f)), 1L).beautifiedFaces.single().trackId
        tracker.update(emptyList(), 2L)
        val b = tracker.update(listOf(face(0.5f, 0.5f, 0.2f)), 3L).beautifiedFaces.single().trackId
        assertNotEquals(a, b)
    }
}

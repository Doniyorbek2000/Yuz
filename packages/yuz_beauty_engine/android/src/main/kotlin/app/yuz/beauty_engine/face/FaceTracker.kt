package app.yuz.beauty_engine.face

/** How many of the visible faces get beauty effects. */
enum class FaceSelectionPolicy { PRIMARY_FACE, ALL_FACES }

/** Stabilized face ready for mask generation. */
class TrackedFace(
    val trackId: Int,
    val landmarks: List<NormalizedPoint>,
    val bounds: NormalizedRect,
)

class FaceTrackingSnapshot(
    val detectedFaceCount: Int,
    val beautifiedFaces: List<TrackedFace>,
    val timestampNanos: Long,
) {
    companion object {
        val EMPTY = FaceTrackingSnapshot(0, emptyList(), 0L)
    }
}

/**
 * Associates detections across frames (greedy IoU matching), stabilizes the
 * mask landmarks of each track with One Euro filters, and applies the
 * multi-face policy with hysteresis so the beautified face does not flicker
 * between two people of similar size.
 *
 * Not thread-safe: call from the detector result thread only.
 */
class FaceTracker(
    private val maxFaces: Int,
    private val policy: FaceSelectionPolicy,
    private val matchIouThreshold: Float = 0.3f,
    private val primarySwitchAreaRatio: Float = 1.3f,
) {
    private class Track(val id: Int, var bounds: NormalizedRect) {
        val filtersX = HashMap<Int, OneEuroFilter>()
        val filtersY = HashMap<Int, OneEuroFilter>()
    }

    private var tracks = emptyList<Track>()
    private var nextTrackId = 1
    private var primaryTrackId: Int? = null

    fun update(detections: List<DetectedFace>, timestampNanos: Long): FaceTrackingSnapshot {
        if (detections.isEmpty()) {
            tracks = emptyList()
            primaryTrackId = null
            return FaceTrackingSnapshot(0, emptyList(), timestampNanos)
        }

        val assigned = matchTracks(detections)
        tracks = assigned.map { it.first }

        val stabilized = assigned.map { (track, detection) ->
            track.bounds = detection.bounds
            TrackedFace(track.id, stabilize(track, detection.landmarks, timestampNanos), detection.bounds)
        }

        val selected = when (policy) {
            FaceSelectionPolicy.ALL_FACES ->
                stabilized.sortedByDescending { it.bounds.area }.take(maxFaces)
            FaceSelectionPolicy.PRIMARY_FACE -> listOf(selectPrimary(stabilized))
        }
        return FaceTrackingSnapshot(detections.size, selected, timestampNanos)
    }

    fun reset() {
        tracks = emptyList()
        primaryTrackId = null
    }

    companion object {
        /** Landmarks consumed by masks and warps; only these are filtered. */
        val STABILIZED_INDICES: IntArray =
            (FaceMaskGeometry.REFERENCED_INDICES + FaceWarpBuilder.REFERENCED_INDICES).distinct().sorted().toIntArray()
    }

    private fun matchTracks(detections: List<DetectedFace>): List<Pair<Track, DetectedFace>> {
        val unmatchedTracks = tracks.toMutableList()
        val result = ArrayList<Pair<Track, DetectedFace>>(detections.size)
        val byArea = detections.sortedByDescending { it.bounds.area }
        for (detection in byArea) {
            val best = unmatchedTracks.maxByOrNull { it.bounds.intersectionOverUnion(detection.bounds) }
            if (best != null && best.bounds.intersectionOverUnion(detection.bounds) >= matchIouThreshold) {
                unmatchedTracks.remove(best)
                result += best to detection
            } else {
                result += Track(nextTrackId++, detection.bounds) to detection
            }
        }
        return result
    }

    private fun selectPrimary(faces: List<TrackedFace>): TrackedFace {
        val largest = faces.maxBy { it.bounds.area }
        val current = faces.firstOrNull { it.trackId == primaryTrackId }
        val chosen = if (current != null && largest.bounds.area < current.bounds.area * primarySwitchAreaRatio) {
            current
        } else {
            largest
        }
        primaryTrackId = chosen.trackId
        return chosen
    }

    private fun stabilize(track: Track, landmarks: List<NormalizedPoint>, timestampNanos: Long): List<NormalizedPoint> {
        val output = landmarks.toMutableList()
        for (index in STABILIZED_INDICES) {
            if (index >= landmarks.size) continue
            val point = landmarks[index]
            val x = track.filtersX.getOrPut(index) { OneEuroFilter() }.filter(point.x.toDouble(), timestampNanos)
            val y = track.filtersY.getOrPut(index) { OneEuroFilter() }.filter(point.y.toDouble(), timestampNanos)
            output[index] = NormalizedPoint(x.toFloat(), y.toFloat())
        }
        return output
    }
}

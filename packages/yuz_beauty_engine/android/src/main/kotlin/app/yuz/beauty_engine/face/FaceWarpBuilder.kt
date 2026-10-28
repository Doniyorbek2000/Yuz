package app.yuz.beauty_engine.face

import kotlin.math.abs

/** Reshape controls, each 0..1 (0 = off). */
data class ReshapeSettings(
    val faceSlim: Float = 0f,
    val jawline: Float = 0f,
    val chin: Float = 0f,
    val eyeEnlarge: Float = 0f,
    val noseSlim: Float = 0f,
    val lips: Float = 0f,
    val forehead: Float = 0f,
) {
    val isIdentity: Boolean
        get() = faceSlim <= 0f && jawline <= 0f && chin <= 0f && eyeEnlarge <= 0f &&
            noseSlim <= 0f && lips <= 0f && forehead <= 0f
}

/**
 * One local deformation for `face_warp.frag`, in landmark space (origin
 * top-left). [radius] is in frame-height units (x distances are multiplied by
 * the aspect ratio before comparing).
 */
data class FaceWarp(
    val centerX: Float,
    val centerY: Float,
    val radius: Float,
    val kind: Kind,
    val offsetX: Float = 0f,
    val offsetY: Float = 0f,
    val strength: Float = 0f,
) {
    enum class Kind(val shaderValue: Float) { BULGE(0f), TRANSLATE(1f) }
}

/**
 * Turns landmarks + [ReshapeSettings] into at most [MAX_WARPS] warps. Every
 * displacement is proportional to the face's own size, so the effect is the
 * same at any distance from the camera; strengths are capped so the maximum
 * setting stays natural.
 */
object FaceWarpBuilder {
    const val MAX_WARPS = 16

    private const val NOSE_TIP = 4
    private const val FOREHEAD = 10
    private const val CHIN = 152
    private const val FACE_LEFT = 234
    private const val FACE_RIGHT = 454
    private val SLIM_LEFT = intArrayOf(93, 132, 58)
    private val SLIM_RIGHT = intArrayOf(323, 361, 288)
    private const val JAW_LEFT = 172
    private const val JAW_RIGHT = 397
    private const val NOSE_LEFT = 129
    private const val NOSE_RIGHT = 358
    private const val UPPER_LIP = 13
    private const val LOWER_LIP = 14
    private const val MOUTH_LEFT = 61
    private const val MOUTH_RIGHT = 291
    private const val LEFT_EYE_OUTER = 33
    private const val LEFT_EYE_INNER = 133
    private const val RIGHT_EYE_OUTER = 263
    private const val RIGHT_EYE_INNER = 362

    val REFERENCED_INDICES: IntArray = (
        intArrayOf(
            NOSE_TIP, FOREHEAD, CHIN, FACE_LEFT, FACE_RIGHT, JAW_LEFT, JAW_RIGHT, NOSE_LEFT, NOSE_RIGHT,
            UPPER_LIP, LOWER_LIP, MOUTH_LEFT, MOUTH_RIGHT, LEFT_EYE_OUTER, LEFT_EYE_INNER, RIGHT_EYE_OUTER,
            RIGHT_EYE_INNER,
        ) + SLIM_LEFT + SLIM_RIGHT + FaceMaskGeometry.LEFT_EYE + FaceMaskGeometry.RIGHT_EYE
        ).distinct().sorted().toIntArray()

    fun build(landmarks: List<NormalizedPoint>, settings: ReshapeSettings, aspect: Float): List<FaceWarp> {
        if (settings.isIdentity || landmarks.size < FaceMaskGeometry.MESH_LANDMARK_COUNT) return emptyList()
        fun p(index: Int) = landmarks[index]

        // Face size in frame-height units.
        val faceWidth = abs(p(FACE_RIGHT).x - p(FACE_LEFT).x) * aspect
        val faceHeight = abs(p(CHIN).y - p(FOREHEAD).y)
        if (faceWidth <= 1e-4f || faceHeight <= 1e-4f) return emptyList()
        val centerX = (p(FACE_LEFT).x + p(FACE_RIGHT).x) / 2f

        val warps = ArrayList<FaceWarp>(MAX_WARPS)

        if (settings.eyeEnlarge > 0f) {
            for ((ring, outer, inner) in listOf(
                Triple(FaceMaskGeometry.LEFT_EYE, LEFT_EYE_OUTER, LEFT_EYE_INNER),
                Triple(FaceMaskGeometry.RIGHT_EYE, RIGHT_EYE_OUTER, RIGHT_EYE_INNER),
            )) {
                val (cx, cy) = FaceMaskGeometry.centroid(landmarks, ring)
                val eyeWidth = abs(p(inner).x - p(outer).x) * aspect
                warps += FaceWarp(cx, cy, eyeWidth * 1.25f, FaceWarp.Kind.BULGE, strength = 0.22f * settings.eyeEnlarge)
            }
        }

        if (settings.faceSlim > 0f) {
            for (index in SLIM_LEFT + SLIM_RIGHT) {
                val point = p(index)
                warps += FaceWarp(
                    point.x,
                    point.y,
                    faceWidth * 0.32f,
                    FaceWarp.Kind.TRANSLATE,
                    offsetX = (centerX - point.x) * 0.10f * settings.faceSlim,
                )
            }
        }

        if (settings.jawline > 0f) {
            for (index in intArrayOf(JAW_LEFT, JAW_RIGHT)) {
                val point = p(index)
                warps += FaceWarp(
                    point.x,
                    point.y,
                    faceWidth * 0.28f,
                    FaceWarp.Kind.TRANSLATE,
                    offsetX = (centerX - point.x) * 0.12f * settings.jawline,
                    offsetY = -0.025f * faceHeight * settings.jawline,
                )
            }
        }

        if (settings.chin > 0f) {
            val chin = p(CHIN)
            warps += FaceWarp(
                chin.x,
                chin.y,
                faceWidth * 0.35f,
                FaceWarp.Kind.TRANSLATE,
                offsetY = -0.05f * faceHeight * settings.chin,
            )
        }

        if (settings.noseSlim > 0f) {
            val noseCenterX = p(NOSE_TIP).x
            val noseWidth = abs(p(NOSE_RIGHT).x - p(NOSE_LEFT).x) * aspect
            for (index in intArrayOf(NOSE_LEFT, NOSE_RIGHT)) {
                val point = p(index)
                warps += FaceWarp(
                    point.x,
                    point.y,
                    noseWidth * 0.9f,
                    FaceWarp.Kind.TRANSLATE,
                    offsetX = (noseCenterX - point.x) * 0.30f * settings.noseSlim,
                )
            }
        }

        if (settings.lips > 0f) {
            val mouthWidth = abs(p(MOUTH_RIGHT).x - p(MOUTH_LEFT).x) * aspect
            warps += FaceWarp(
                (p(UPPER_LIP).x + p(LOWER_LIP).x) / 2f,
                (p(UPPER_LIP).y + p(LOWER_LIP).y) / 2f,
                mouthWidth * 0.75f,
                FaceWarp.Kind.BULGE,
                strength = 0.15f * settings.lips,
            )
        }

        if (settings.forehead > 0f) {
            val top = p(FOREHEAD)
            warps += FaceWarp(
                top.x,
                top.y,
                faceWidth * 0.5f,
                FaceWarp.Kind.TRANSLATE,
                offsetY = 0.05f * faceHeight * settings.forehead,
            )
        }

        check(warps.size <= MAX_WARPS) { "too many warps: ${warps.size}" }
        return warps
    }
}

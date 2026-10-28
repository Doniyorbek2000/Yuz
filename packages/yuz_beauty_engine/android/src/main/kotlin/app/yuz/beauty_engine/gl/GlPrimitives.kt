package app.yuz.beauty_engine.gl

import android.content.res.AssetManager
import android.opengl.GLES11Ext
import android.opengl.GLES30
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

object GlUtil {
    fun checkError(operation: String) {
        val error = GLES30.glGetError()
        if (error != GLES30.GL_NO_ERROR) {
            throw GlException("$operation: glError 0x${Integer.toHexString(error)}")
        }
    }

    fun createExternalTexture(): Int {
        val ids = IntArray(1)
        GLES30.glGenTextures(1, ids, 0)
        GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, ids[0])
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
        checkError("createExternalTexture")
        return ids[0]
    }

    fun deleteTexture(id: Int) {
        GLES30.glDeleteTextures(1, intArrayOf(id), 0)
    }
}

/** Loads shader sources bundled under assets/yuz_beauty_engine/shaders. */
class ShaderLibrary(private val assets: AssetManager) {
    fun load(name: String): String =
        assets.open("$ASSET_DIRECTORY/$name").bufferedReader().use { it.readText() }

    private companion object {
        const val ASSET_DIRECTORY = "yuz_beauty_engine/shaders"
    }
}

class GlProgram(vertexSource: String, fragmentSource: String, private val label: String) {
    val handle: Int
    private val uniformLocations = HashMap<String, Int>()

    init {
        val vertex = compile(GLES30.GL_VERTEX_SHADER, vertexSource)
        val fragment = compile(GLES30.GL_FRAGMENT_SHADER, fragmentSource)
        handle = GLES30.glCreateProgram()
        GLES30.glAttachShader(handle, vertex)
        GLES30.glAttachShader(handle, fragment)
        GLES30.glLinkProgram(handle)
        val status = IntArray(1)
        GLES30.glGetProgramiv(handle, GLES30.GL_LINK_STATUS, status, 0)
        GLES30.glDeleteShader(vertex)
        GLES30.glDeleteShader(fragment)
        if (status[0] == 0) {
            val log = GLES30.glGetProgramInfoLog(handle)
            GLES30.glDeleteProgram(handle)
            throw GlException("Link failed for $label: $log")
        }
    }

    fun use() {
        GLES30.glUseProgram(handle)
    }

    fun location(name: String): Int = uniformLocations.getOrPut(name) {
        GLES30.glGetUniformLocation(handle, name)
    }

    fun setFloat(name: String, value: Float) = GLES30.glUniform1f(location(name), value)

    fun setVec2(name: String, x: Float, y: Float) = GLES30.glUniform2f(location(name), x, y)

    fun setVec2Array(name: String, values: FloatArray) =
        GLES30.glUniform2fv(location(name), values.size / 2, values, 0)

    fun setVec3(name: String, values: FloatArray) = GLES30.glUniform3f(location(name), values[0], values[1], values[2])

    fun setVec4(name: String, values: FloatArray) =
        GLES30.glUniform4f(location(name), values[0], values[1], values[2], values[3])

    fun setVec4Array(name: String, values: FloatArray) =
        GLES30.glUniform4fv(location(name), values.size / 4, values, 0)

    fun setMatrix(name: String, matrix: FloatArray) =
        GLES30.glUniformMatrix4fv(location(name), 1, false, matrix, 0)

    fun bindTexture(name: String, unit: Int, target: Int, textureId: Int) {
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0 + unit)
        GLES30.glBindTexture(target, textureId)
        GLES30.glUniform1i(location(name), unit)
    }

    fun release() {
        GLES30.glDeleteProgram(handle)
    }

    private fun compile(type: Int, source: String): Int {
        val shader = GLES30.glCreateShader(type)
        GLES30.glShaderSource(shader, source)
        GLES30.glCompileShader(shader)
        val status = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0)
        if (status[0] == 0) {
            val log = GLES30.glGetShaderInfoLog(shader)
            GLES30.glDeleteShader(shader)
            throw GlException("Compile failed for $label: $log")
        }
        return shader
    }
}

/** RGBA8 texture + framebuffer pair used as a render target. */
class GlRenderTarget(val width: Int, val height: Int) {
    val textureId: Int
    val framebufferId: Int

    init {
        val textures = IntArray(1)
        GLES30.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
        GLES30.glTexStorage2D(GLES30.GL_TEXTURE_2D, 1, GLES30.GL_RGBA8, width, height)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)

        val framebuffers = IntArray(1)
        GLES30.glGenFramebuffers(1, framebuffers, 0)
        framebufferId = framebuffers[0]
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebufferId)
        GLES30.glFramebufferTexture2D(
            GLES30.GL_FRAMEBUFFER,
            GLES30.GL_COLOR_ATTACHMENT0,
            GLES30.GL_TEXTURE_2D,
            textureId,
            0,
        )
        val status = GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER)
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
        if (status != GLES30.GL_FRAMEBUFFER_COMPLETE) {
            release()
            throw GlException("Framebuffer incomplete: 0x${Integer.toHexString(status)}")
        }
    }

    fun bind() {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebufferId)
        GLES30.glViewport(0, 0, width, height)
    }

    /** Reads the target as tightly packed RGBA rows, bottom row first (GL order). */
    fun readPixels(): ByteBuffer {
        val buffer = ByteBuffer.allocateDirect(width * height * 4).order(ByteOrder.nativeOrder())
        bind()
        GLES30.glPixelStorei(GLES30.GL_PACK_ALIGNMENT, 1)
        GLES30.glReadPixels(0, 0, width, height, GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, buffer)
        GlUtil.checkError("readPixels")
        buffer.rewind()
        return buffer
    }

    fun release() {
        GLES30.glDeleteFramebuffers(1, intArrayOf(framebufferId), 0)
        GLES30.glDeleteTextures(1, intArrayOf(textureId), 0)
    }
}

/** Interleaved full-screen quad: position (xy) + texcoord (uv). */
class FullScreenQuad {
    private val vertices: FloatBuffer = ByteBuffer
        .allocateDirect(QUAD.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(QUAD)
            position(0)
        }
    private val vertexArray: Int
    private val vertexBuffer: Int

    init {
        val arrays = IntArray(1)
        GLES30.glGenVertexArrays(1, arrays, 0)
        vertexArray = arrays[0]
        val buffers = IntArray(1)
        GLES30.glGenBuffers(1, buffers, 0)
        vertexBuffer = buffers[0]

        GLES30.glBindVertexArray(vertexArray)
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vertexBuffer)
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, QUAD.size * 4, vertices, GLES30.GL_STATIC_DRAW)
        GLES30.glEnableVertexAttribArray(0)
        GLES30.glVertexAttribPointer(0, 2, GLES30.GL_FLOAT, false, 16, 0)
        GLES30.glEnableVertexAttribArray(1)
        GLES30.glVertexAttribPointer(1, 2, GLES30.GL_FLOAT, false, 16, 8)
        GLES30.glBindVertexArray(0)
        GlUtil.checkError("FullScreenQuad")
    }

    fun draw() {
        GLES30.glBindVertexArray(vertexArray)
        GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
        GLES30.glBindVertexArray(0)
    }

    fun release() {
        GLES30.glDeleteBuffers(1, intArrayOf(vertexBuffer), 0)
        GLES30.glDeleteVertexArrays(1, intArrayOf(vertexArray), 0)
    }

    private companion object {
        val QUAD = floatArrayOf(
            -1f, -1f, 0f, 0f,
            1f, -1f, 1f, 0f,
            -1f, 1f, 0f, 1f,
            1f, 1f, 1f, 1f,
        )
    }
}

/** Several RGBA8 textures bound as colour attachments of one framebuffer (MRT). */
class GlMultiTarget(val width: Int, val height: Int, count: Int) {
    val textureIds = IntArray(count)
    val framebufferId: Int

    init {
        GLES30.glGenTextures(count, textureIds, 0)
        val framebuffers = IntArray(1)
        GLES30.glGenFramebuffers(1, framebuffers, 0)
        framebufferId = framebuffers[0]
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebufferId)
        val attachments = IntArray(count)
        for (i in 0 until count) {
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureIds[i])
            GLES30.glTexStorage2D(GLES30.GL_TEXTURE_2D, 1, GLES30.GL_RGBA8, width, height)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
            attachments[i] = GLES30.GL_COLOR_ATTACHMENT0 + i
            GLES30.glFramebufferTexture2D(GLES30.GL_FRAMEBUFFER, attachments[i], GLES30.GL_TEXTURE_2D, textureIds[i], 0)
        }
        GLES30.glDrawBuffers(count, attachments, 0)
        val status = GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER)
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
        if (status != GLES30.GL_FRAMEBUFFER_COMPLETE) {
            release()
            throw GlException("MRT framebuffer incomplete: 0x${Integer.toHexString(status)}")
        }
    }

    fun bind() {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebufferId)
        GLES30.glViewport(0, 0, width, height)
    }

    fun release() {
        GLES30.glDeleteFramebuffers(1, intArrayOf(framebufferId), 0)
        GLES30.glDeleteTextures(textureIds.size, textureIds, 0)
    }
}

/** Wraps an existing texture as a single-attachment render target (for in-place ping-pong). */
class GlTextureTarget(val textureId: Int, val width: Int, val height: Int) {
    val framebufferId: Int

    init {
        val framebuffers = IntArray(1)
        GLES30.glGenFramebuffers(1, framebuffers, 0)
        framebufferId = framebuffers[0]
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebufferId)
        GLES30.glFramebufferTexture2D(GLES30.GL_FRAMEBUFFER, GLES30.GL_COLOR_ATTACHMENT0, GLES30.GL_TEXTURE_2D, textureId, 0)
        val status = GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER)
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
        if (status != GLES30.GL_FRAMEBUFFER_COMPLETE) {
            GLES30.glDeleteFramebuffers(1, intArrayOf(framebufferId), 0)
            throw GlException("Texture framebuffer incomplete: 0x${Integer.toHexString(status)}")
        }
    }

    fun bind() {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebufferId)
        GLES30.glViewport(0, 0, width, height)
    }

    fun release() {
        GLES30.glDeleteFramebuffers(1, intArrayOf(framebufferId), 0)
    }
}

/** 512x512 RGBA8 colour lookup table texture. */
class GlLutTexture {
    val textureId: Int

    init {
        val ids = IntArray(1)
        GLES30.glGenTextures(1, ids, 0)
        textureId = ids[0]
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
        GLES30.glTexStorage2D(GLES30.GL_TEXTURE_2D, 1, GLES30.GL_RGBA8, SIZE, SIZE)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
    }

    fun upload(rgba: ByteArray) {
        require(rgba.size == BYTES) { "LUT must be $BYTES bytes, got ${rgba.size}" }
        val buffer = ByteBuffer.allocateDirect(BYTES).order(ByteOrder.nativeOrder()).put(rgba)
        buffer.position(0)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
        GLES30.glPixelStorei(GLES30.GL_UNPACK_ALIGNMENT, 1)
        GLES30.glTexSubImage2D(GLES30.GL_TEXTURE_2D, 0, 0, 0, SIZE, SIZE, GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, buffer)
        GlUtil.checkError("LUT upload")
    }

    fun release() {
        GLES30.glDeleteTextures(1, intArrayOf(textureId), 0)
    }

    companion object {
        const val SIZE = 512
        const val BYTES = SIZE * SIZE * 4
    }
}

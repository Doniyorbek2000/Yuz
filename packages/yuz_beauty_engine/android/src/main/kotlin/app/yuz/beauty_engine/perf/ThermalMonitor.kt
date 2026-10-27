package app.yuz.beauty_engine.perf

import android.content.Context
import android.os.Build
import android.os.PowerManager
import java.util.concurrent.Executor

/**
 * Maps PowerManager thermal status to 0 (nominal) .. 3 (critical), the same
 * scale the iOS engine derives from ProcessInfo.ThermalState.
 */
class ThermalMonitor(context: Context, private val executor: Executor, private val onChange: (Int) -> Unit) {
    private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private var listener: PowerManager.OnThermalStatusChangedListener? = null

    @Volatile
    var level: Int = 0
        private set

    fun start() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        level = normalize(powerManager.currentThermalStatus)
        val callback = PowerManager.OnThermalStatusChangedListener { status ->
            val normalized = normalize(status)
            if (normalized != level) {
                level = normalized
                onChange(normalized)
            }
        }
        powerManager.addThermalStatusListener(executor, callback)
        listener = callback
    }

    fun stop() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        listener?.let { powerManager.removeThermalStatusListener(it) }
        listener = null
    }

    private fun normalize(status: Int): Int = when (status) {
        PowerManager.THERMAL_STATUS_NONE, PowerManager.THERMAL_STATUS_LIGHT -> 0
        PowerManager.THERMAL_STATUS_MODERATE -> 1
        PowerManager.THERMAL_STATUS_SEVERE -> 2
        else -> 3
    }

    companion object {
        /** At or above this level face tracking runs every other frame. */
        const val REDUCED_DETECTION_LEVEL = 2

        /** At this level face tracking stops; colour-only skin detection remains. */
        const val CRITICAL_LEVEL = 3
    }
}

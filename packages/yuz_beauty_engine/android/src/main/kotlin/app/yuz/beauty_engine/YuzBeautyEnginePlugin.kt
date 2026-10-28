package app.yuz.beauty_engine

import app.yuz.beauty_engine.generated.BeautyEngineEventsApi
import app.yuz.beauty_engine.generated.BeautyEngineHostApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Registers the Pigeon host API and owns the controller for one Flutter
 * engine. The activity is only needed for the screen-brightness override.
 */
class YuzBeautyEnginePlugin : FlutterPlugin, ActivityAware {
    private var controller: BeautyEngineController? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val engineController = BeautyEngineController(
            context = binding.applicationContext,
            textureRegistry = binding.textureRegistry,
            events = BeautyEngineEventsApi(binding.binaryMessenger),
        )
        controller = engineController
        BeautyEngineHostApi.setUp(binding.binaryMessenger, engineController)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        BeautyEngineHostApi.setUp(binding.binaryMessenger, null)
        controller?.shutdown()
        controller = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        controller?.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        controller?.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        controller?.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        controller?.activity = null
    }
}

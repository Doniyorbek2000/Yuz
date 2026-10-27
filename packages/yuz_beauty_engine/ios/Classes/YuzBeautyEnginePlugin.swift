import Flutter
import UIKit

public final class YuzBeautyEnginePlugin: NSObject, FlutterPlugin {
  private let controller: BeautyEngineController
  private let messenger: FlutterBinaryMessenger

  private init(registrar: FlutterPluginRegistrar) {
    messenger = registrar.messenger()
    controller = BeautyEngineController(
      registry: registrar.textures(), events: BeautyEngineEventsApi(binaryMessenger: messenger))
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = YuzBeautyEnginePlugin(registrar: registrar)
    BeautyEngineHostApiSetup.setUp(binaryMessenger: plugin.messenger, api: plugin.controller)
    registrar.publish(plugin)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    BeautyEngineHostApiSetup.setUp(binaryMessenger: messenger, api: nil)
    let controller = controller
    Task { try? await controller.dispose() }
  }
}

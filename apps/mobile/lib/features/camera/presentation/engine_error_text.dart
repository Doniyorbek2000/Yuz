import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../../l10n/generated/app_localizations.dart';

extension EngineErrorText on EngineErrorCode {
  String message(AppLocalizations l10n) => switch (this) {
    EngineErrorCode.permissionDenied => l10n.errorPermissionDenied,
    EngineErrorCode.cameraUnavailable => l10n.errorCameraUnavailable,
    EngineErrorCode.cameraInUse => l10n.errorCameraInUse,
    EngineErrorCode.cameraDisconnected => l10n.errorCameraDisconnected,
    EngineErrorCode.gpuInitializationFailed => l10n.errorGpu,
    EngineErrorCode.faceModelUnavailable => l10n.cameraTrackingUnavailable,
    EngineErrorCode.captureFailed => l10n.errorCaptureFailed,
    EngineErrorCode.thermalThrottling => l10n.errorThermal,
    EngineErrorCode.unknown => l10n.errorUnknown,
  };
}

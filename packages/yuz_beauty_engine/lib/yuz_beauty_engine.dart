/// Native real-time beauty camera engine.
///
/// Camera frames are processed on the GPU natively (OpenGL ES 3 on Android,
/// Metal on iOS) and rendered into a Flutter [Texture]; only control data and
/// low-frequency telemetry cross the platform channel.
library;

export 'src/beauty_camera_preview.dart';
export 'src/beauty_engine.dart';
export 'src/beauty_parameters_factory.dart';
export 'src/color_lut.dart';
export 'src/generated/beauty_engine_api.g.dart'
    show
        BeautyParameters,
        CameraCapabilities,
        CameraLens,
        CaptureAspectRatio,
        EngineConfig,
        EngineError,
        EngineErrorCode,
        FaceTrackingStatus,
        FlashMode,
        MultiFacePolicy,
        PerformanceSample,
        PhotoCaptureResult,
        PreviewDescriptor,
        PreviewQuality,
        BeautyEngineHostApi;

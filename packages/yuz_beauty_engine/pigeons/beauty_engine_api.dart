// Contract between Flutter and the native beauty engine.
//
// Regenerate after editing:
//   dart run pigeon --input pigeons/beauty_engine_api.dart
//
// Rules:
// - Only control data and low-frequency telemetry cross this boundary.
// - Camera frames never cross it; they are rendered natively into a
//   Flutter texture identified by [PreviewDescriptor.textureId].
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/beauty_engine_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/app/yuz/beauty_engine/generated/BeautyEngineApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'app.yuz.beauty_engine.generated',
      errorClassName: 'BeautyEngineFlutterError',
    ),
    swiftOut: 'ios/Classes/Generated/BeautyEngineApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'BeautyEngineFlutterError'),
    dartPackageName: 'yuz_beauty_engine',
  ),
)
enum CameraLens { front, back }

enum FlashMode { off, auto, on, torch }

/// Capture aspect ratio. Preview and analysis streams always share it so
/// landmark coordinates map 1:1 onto the rendered frame.
enum CaptureAspectRatio { ratio4x3, ratio16x9 }

/// Target preview resolution (long edge). The device may pick the nearest
/// supported size; the actual size is reported in [PreviewDescriptor].
enum PreviewQuality { low720, high1080 }

/// Which faces receive beauty effects when several are visible.
enum MultiFacePolicy {
  /// Only the most prominent face (largest area, with hysteresis).
  primaryFace,

  /// Every tracked face up to [EngineConfig.maxFaces].
  allFaces,
}

enum EngineErrorCode {
  permissionDenied,
  cameraUnavailable,
  cameraInUse,
  cameraDisconnected,
  gpuInitializationFailed,
  faceModelUnavailable,
  captureFailed,
  thermalThrottling,
  unknown,
}

class EngineConfig {
  EngineConfig({
    required this.lens,
    required this.aspectRatio,
    required this.quality,
    required this.enableFaceTracking,
    required this.maxFaces,
    required this.multiFacePolicy,
  });

  CameraLens lens;
  CaptureAspectRatio aspectRatio;
  PreviewQuality quality;
  bool enableFaceTracking;

  /// Clamped natively to 1..4.
  int maxFaces;
  MultiFacePolicy multiFacePolicy;
}

class PreviewDescriptor {
  PreviewDescriptor({
    required this.textureId,
    required this.width,
    required this.height,
    required this.lens,
    required this.isMirrored,
    required this.faceTrackingAvailable,
  });

  int textureId;

  /// Upright (display-oriented) size of the rendered texture in pixels.
  int width;
  int height;
  CameraLens lens;
  bool isMirrored;

  /// False when the face model failed to load; beauty then falls back to
  /// colour-based skin detection only.
  bool faceTrackingAvailable;
}

/// All values are normalized to 0..1 (the UI maps 0..100 sliders). Every
/// effect is off at 0; texturePreservation only matters while smoothing.
class BeautyParameters {
  BeautyParameters({
    required this.skinSmoothing,
    required this.texturePreservation,
    required this.skinBrightening,
    required this.skinTone,
    required this.blemishReduction,
    required this.shineReduction,
    required this.glow,
    required this.eyeBrightening,
    required this.teethWhitening,
    required this.darkCircles,
    required this.faceSlim,
    required this.jawline,
    required this.chin,
    required this.eyeEnlarge,
    required this.noseSlim,
    required this.lips,
    required this.forehead,
    required this.lipstick,
    required this.blush,
    required this.eyebrows,
    required this.eyeshadow,
    required this.eyeliner,
    required this.makeupIntensity,
    required this.lipstickColor,
    required this.blushColor,
    required this.eyebrowColor,
    required this.eyeshadowColor,
    required this.eyelinerColor,
    required this.filterIntensity,
    required this.sharpen,
  });

  // Skin
  double skinSmoothing;
  double texturePreservation;
  double skinBrightening;
  double skinTone;
  double blemishReduction;
  double shineReduction;
  double glow;

  // Face details
  double eyeBrightening;
  double teethWhitening;
  double darkCircles;

  // Reshape (requires face tracking)
  double faceSlim;
  double jawline;
  double chin;
  double eyeEnlarge;
  double noseSlim;
  double lips;
  double forehead;

  // Makeup (requires face tracking); colours are 0xAARRGGBB
  double lipstick;
  double blush;
  double eyebrows;
  double eyeshadow;
  double eyeliner;
  double makeupIntensity;
  int lipstickColor;
  int blushColor;
  int eyebrowColor;
  int eyeshadowColor;
  int eyelinerColor;

  /// Strength of the colour LUT set with setColorLut (0 = off).
  double filterIntensity;

  /// Unsharp-mask strength (skin being smoothed is protected).
  double sharpen;
}

/// Still-image job: runs the same GPU pipeline as the camera on a photo.
class ImageProcessingRequest {
  ImageProcessingRequest({
    required this.inputPath,
    required this.outputPath,
    required this.maxLongEdge,
    required this.parameters,
    required this.lutRgba,
    required this.jpegQuality,
    required this.maxFaces,
  });

  /// JPEG/PNG/HEIC file; EXIF orientation is applied.
  String inputPath;

  /// Destination JPEG.
  String outputPath;

  /// Long edge of the output; 0 = original size (capped at the GPU's maximum
  /// texture size).
  int maxLongEdge;
  BeautyParameters parameters;

  /// Optional 512x512 RGBA LUT for parameters.filterIntensity.
  Uint8List? lutRgba;

  /// 1..100
  int jpegQuality;

  /// Faces to beautify (all faces policy, clamped to 1..4).
  int maxFaces;
}

class ImageProcessingResult {
  ImageProcessingResult({
    required this.outputPath,
    required this.width,
    required this.height,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.faceCount,
    required this.faceTrackingAvailable,
  });

  String outputPath;

  /// Output size (upright).
  int width;
  int height;

  /// Original size after EXIF orientation.
  int sourceWidth;
  int sourceHeight;
  int faceCount;
  bool faceTrackingAvailable;
}

class CameraCapabilities {
  CameraCapabilities({
    required this.hasFrontCamera,
    required this.hasBackCamera,
    required this.hasFlash,
    required this.minZoomRatio,
    required this.maxZoomRatio,
    required this.minExposureBias,
    required this.maxExposureBias,
  });

  bool hasFrontCamera;
  bool hasBackCamera;
  bool hasFlash;
  double minZoomRatio;
  double maxZoomRatio;

  /// Exposure compensation in EV.
  double minExposureBias;
  double maxExposureBias;
}

class PhotoCaptureResult {
  PhotoCaptureResult({
    required this.filePath,
    required this.width,
    required this.height,
  });

  String filePath;
  int width;
  int height;
}

class FaceTrackingStatus {
  FaceTrackingStatus({
    required this.faceCount,
    required this.beautifiedFaceCount,
    required this.timestampMillis,
  });

  int faceCount;
  int beautifiedFaceCount;
  int timestampMillis;
}

/// Measured on the native side; sent at most once per second.
class PerformanceSample {
  PerformanceSample({
    required this.renderedFps,
    required this.cameraFps,
    required this.averageGpuFrameMillis,
    required this.averageDetectorMillis,
    required this.droppedFrames,
    required this.thermalLevel,
  });

  double renderedFps;
  double cameraFps;
  double averageGpuFrameMillis;
  double averageDetectorMillis;
  int droppedFrames;

  /// 0 = nominal … 3 = critical (normalized across platforms).
  int thermalLevel;
}

class EngineError {
  EngineError({required this.code, required this.message});

  EngineErrorCode code;
  String message;
}

@HostApi()
abstract class BeautyEngineHostApi {
  @async
  PreviewDescriptor initialize(EngineConfig config);

  @async
  PreviewDescriptor switchLens(CameraLens lens);

  CameraCapabilities getCapabilities();

  void setBeautyParameters(BeautyParameters parameters);

  /// Sets a 512x512 RGBA lookup table (8x8 tiles of 64^3, first row = top),
  /// i.e. exactly 1048576 bytes. null removes the filter.
  void setColorLut(Uint8List? rgba512);

  void setFlashMode(FlashMode mode);

  void setZoomRatio(double ratio);

  void setExposureBias(double ev);

  @async
  PhotoCaptureResult capturePhoto(String outputFilePath);

  /// Independent of the camera session; jobs run one at a time.
  @async
  ImageProcessingResult processImage(ImageProcessingRequest request);

  @async
  void pause();

  @async
  void resume();

  @async
  void dispose();
}

@FlutterApi()
abstract class BeautyEngineEventsApi {
  void onFaceTrackingStatus(FaceTrackingStatus status);

  void onPerformanceSample(PerformanceSample sample);

  void onEngineError(EngineError error);
}

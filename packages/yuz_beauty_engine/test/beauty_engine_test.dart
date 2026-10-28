import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

class FakeHostApi implements BeautyEngineHostApi {
  final List<BeautyParameters> appliedParameters = [];
  Completer<void>? parameterGate;
  Object? initializeError;
  int disposeCalls = 0;

  @override
  Future<PreviewDescriptor> initialize(EngineConfig config) async {
    if (initializeError != null) throw initializeError!;
    return PreviewDescriptor(
      textureId: 7,
      width: 1080,
      height: 1920,
      lens: config.lens,
      isMirrored: config.lens == CameraLens.front,
      faceTrackingAvailable: true,
    );
  }

  @override
  Future<void> setBeautyParameters(BeautyParameters parameters) async {
    appliedParameters.add(parameters);
    final gate = parameterGate;
    if (gate != null) await gate.future;
  }

  ImageProcessingRequest? lastImageRequest;

  @override
  Future<ImageProcessingResult> processImage(
    ImageProcessingRequest request,
  ) async {
    lastImageRequest = request;
    return ImageProcessingResult(
      outputPath: request.outputPath,
      width: 100,
      height: 50,
      sourceWidth: 400,
      sourceHeight: 200,
      faceCount: 1,
      faceTrackingAvailable: true,
    );
  }

  VideoRecordingOptions? lastRecording;
  VideoExportRequest? lastExport;
  String? cancelledJob;

  @override
  Future<VideoExportResult> exportVideo(VideoExportRequest request) async {
    lastExport = request;
    return VideoExportResult(
      outputPath: request.outputPath,
      durationMillis: 3000,
      width: 1080,
      height: 1920,
      hasAudio: true,
    );
  }

  @override
  Future<void> cancelVideoExport(String jobId) async => cancelledJob = jobId;

  @override
  Future<void> startRecording(VideoRecordingOptions options) async =>
      lastRecording = options;

  @override
  Future<VideoRecordingResult> stopRecording() async {
    final options = lastRecording;
    if (options == null) {
      throw PlatformException(
        code: 'RECORDING_FAILED',
        message: 'Not recording',
      );
    }
    return VideoRecordingResult(
      filePath: options.outputFilePath,
      durationMillis: 1500,
      width: 1080,
      height: 1920,
      hasAudio: options.recordAudio,
    );
  }

  Uint8List? lut;
  int lutCalls = 0;

  @override
  Future<void> setColorLut(Uint8List? rgba512) async {
    lutCalls++;
    lut = rgba512;
  }

  @override
  Future<void> dispose() async => disposeCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BeautyParameters params(double smoothing) =>
    neutralBeautyParameters()..skinSmoothing = smoothing;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize returns the native preview descriptor', () async {
    final engine = BeautyEngine(
      hostApi: FakeHostApi(),
      registerEventHandlers: false,
    );
    final descriptor = await engine.initialize(
      EngineConfig(
        lens: CameraLens.front,
        aspectRatio: CaptureAspectRatio.ratio16x9,
        quality: PreviewQuality.high1080,
        enableFaceTracking: true,
        maxFaces: 1,
        multiFacePolicy: MultiFacePolicy.primaryFace,
      ),
    );
    expect(descriptor.textureId, 7);
    expect(descriptor.isMirrored, isTrue);
  });

  test('platform errors are mapped to typed exceptions', () async {
    final host = FakeHostApi()
      ..initializeError = PlatformException(
        code: 'PERMISSION_DENIED',
        message: 'denied',
      );
    final engine = BeautyEngine(hostApi: host, registerEventHandlers: false);
    await expectLater(
      engine.initialize(
        EngineConfig(
          lens: CameraLens.back,
          aspectRatio: CaptureAspectRatio.ratio4x3,
          quality: PreviewQuality.low720,
          enableFaceTracking: false,
          maxFaces: 1,
          multiFacePolicy: MultiFacePolicy.primaryFace,
        ),
      ),
      throwsA(
        isA<BeautyEngineException>().having(
          (error) => error.code,
          'code',
          EngineErrorCode.permissionDenied,
        ),
      ),
    );
  });

  test('unknown platform codes map to EngineErrorCode.unknown', () {
    final error = BeautyEngineException.fromPlatform(
      PlatformException(code: 'WHAT'),
    );
    expect(error.code, EngineErrorCode.unknown);
  });

  test('parameter updates coalesce while a call is in flight', () async {
    final host = FakeHostApi()..parameterGate = Completer<void>();
    final engine = BeautyEngine(hostApi: host, registerEventHandlers: false);

    final first = engine.setBeautyParameters(params(0.1));
    unawaited(engine.setBeautyParameters(params(0.2)));
    unawaited(engine.setBeautyParameters(params(0.3)));
    unawaited(engine.setBeautyParameters(params(0.4)));
    host.parameterGate!.complete();
    host.parameterGate = null;
    await first;

    expect(host.appliedParameters.map((p) => p.skinSmoothing), [0.1, 0.4]);
  });

  test('events are forwarded to broadcast streams', () async {
    final engine = BeautyEngine(
      hostApi: FakeHostApi(),
      registerEventHandlers: false,
    );
    final statuses = <FaceTrackingStatus>[];
    final subscription = engine.faceStatus.listen(statuses.add);
    engine.onFaceTrackingStatus(
      FaceTrackingStatus(
        faceCount: 2,
        beautifiedFaceCount: 1,
        timestampMillis: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(statuses.single.faceCount, 2);
    await subscription.cancel();
  });

  test('close disposes native resources once and closes streams', () async {
    final host = FakeHostApi();
    final engine = BeautyEngine(hostApi: host, registerEventHandlers: false);
    await engine.close();
    await engine.close();
    expect(host.disposeCalls, 1);
    expect(await engine.errors.isEmpty, isTrue);
  });

  test('setColorLut forwards valid tables and rejects wrong sizes before the platform call', () async {
    final host = FakeHostApi();
    final engine = BeautyEngine(hostApi: host, registerEventHandlers: false);
    await engine.setColorLut(Uint8List(ColorLut.byteLength));
    await engine.setColorLut(null);
    expect(host.lutCalls, 2);
    expect(host.lut, isNull);
    expect(() => engine.setColorLut(Uint8List(10)), throwsArgumentError);
    expect(host.lutCalls, 2);
  });

  test(
    'processImage forwards a clamped request and validates inputs',
    () async {
      final host = FakeHostApi();
      final engine = BeautyEngine(hostApi: host, registerEventHandlers: false);
      final result = await engine.processImage(
        inputPath: '/in.jpg',
        outputPath: '/out.jpg',
        parameters: neutralBeautyParameters(),
        maxLongEdge: 1600,
        jpegQuality: 300,
        maxFaces: 9,
      );
      expect(result.width, 100);
      expect(host.lastImageRequest!.maxLongEdge, 1600);
      expect(host.lastImageRequest!.jpegQuality, 100);
      expect(host.lastImageRequest!.maxFaces, 4);
      expect(
        () => engine.processImage(
          inputPath: 'a',
          outputPath: 'b',
          parameters: neutralBeautyParameters(),
          maxLongEdge: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => engine.processImage(
          inputPath: 'a',
          outputPath: 'b',
          parameters: neutralBeautyParameters(),
          lutRgba: Uint8List(3),
        ),
        throwsArgumentError,
      );
    },
  );

  test('recording forwards options and maps recording errors', () async {
    final host = FakeHostApi();
    final engine = BeautyEngine(hostApi: host, registerEventHandlers: false);

    await expectLater(
      engine.stopRecording(),
      throwsA(
        isA<BeautyEngineException>().having(
          (e) => e.code,
          'code',
          EngineErrorCode.recordingFailed,
        ),
      ),
    );

    await engine.startRecording(outputPath: '/v.mp4', recordAudio: false);
    expect(host.lastRecording!.outputFilePath, '/v.mp4');
    expect(host.lastRecording!.recordAudio, isFalse);
    expect(host.lastRecording!.videoBitrate, 0);

    final result = await engine.stopRecording();
    expect(result.durationMillis, 1500);
    expect(result.hasAudio, isFalse);
    expect(
      () => engine.startRecording(outputPath: '/v.mp4', videoBitrate: -1),
      throwsArgumentError,
    );
  });

  test('exportVideo validates the edit and streams progress', () async {
    final host = FakeHostApi();
    final engine = BeautyEngine(hostApi: host, registerEventHandlers: false);
    VideoExportRequest request({List<VideoClipSpec>? clips, Uint8List? lut}) =>
        VideoExportRequest(
          jobId: 'job-1',
          clips:
              clips ??
              [
                VideoClipSpec(
                  path: '/a.mp4',
                  startMillis: 0,
                  endMillis: 1000,
                  speed: 1,
                ),
              ],
          outputPath: '/out.mp4',
          parameters: neutralBeautyParameters(),
          lutRgba: lut,
          applyBeauty: true,
          overlays: const [],
          musicPath: null,
          musicVolume: 0,
          originalVolume: 1,
          maxLongEdge: 1920,
        );

    expect(
      () => engine.exportVideo(request(clips: const [])),
      throwsArgumentError,
    );
    expect(
      () => engine.exportVideo(
        request(
          clips: [
            VideoClipSpec(path: '/a', startMillis: 0, endMillis: 10, speed: 8),
          ],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.exportVideo(
        request(
          clips: [
            VideoClipSpec(
              path: '/a',
              startMillis: 500,
              endMillis: 500,
              speed: 1,
            ),
          ],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.exportVideo(request(lut: Uint8List(4))),
      throwsArgumentError,
    );
    expect(host.lastExport, isNull);

    final progress = <double>[];
    final subscription = engine.exportProgress.listen(
      (p) => progress.add(p.progress),
    );
    engine
      ..onVideoExportProgress('job-1', 0.5)
      ..onVideoExportProgress('job-1', 1.4);
    final result = await engine.exportVideo(request());
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(result.durationMillis, 3000);
    expect(host.lastExport!.jobId, 'job-1');
    expect(progress, [0.5, 1.0]);

    await engine.cancelVideoExport('job-1');
    expect(host.cancelledJob, 'job-1');
  });
}

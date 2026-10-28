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
}

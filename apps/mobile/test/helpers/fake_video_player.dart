import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// In-memory video player: every source "plays" a 1080×1920, 4.2 s clip.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> calls = [];
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _nextId = 1;

  /// When set, creation fails like an unreadable file.
  bool failCreation = false;

  static FakeVideoPlayerPlatform install() {
    final fake = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
    return fake;
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (failCreation) throw Exception('unreadable video');
    final id = _nextId++;
    calls.add('create:${options.dataSource.uri}');
    final controller = StreamController<VideoEvent>();
    _events[id] = controller;
    controller.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(milliseconds: 4200),
        size: const Size(1080, 1920),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose:$playerId');
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async => calls.add('looping:$looping');

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async => calls.add('seek:${position.inMilliseconds}');

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.expand();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

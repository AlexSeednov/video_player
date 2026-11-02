@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player_web/hls_options.dart';

/// Public controller options must reach creation before any HLS loading,
/// and live changes must not recreate the platform player.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Platform platform;
  late VideoPlayerPlatform previous;
  late VideoPlayerController controller;
  const initial = VideoPlayerWebHlsOptions(
    maxForwardBufferDuration: Duration(seconds: 120),
    backBufferDuration: Duration(seconds: 30),
  );

  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = _Platform();
    VideoPlayerPlatform.instance = platform;
    controller = VideoPlayerController.networkUrl(
      Uri.parse('https://example.invalid/master.m3u8'),
      videoPlayerOptions: VideoPlayerOptions(webOptions: initial),
    );
  });
  tearDown(() async {
    await controller.dispose();
    await platform.events.close();
    VideoPlayerPlatform.instance = previous;
  });

  test(
    'options arrive at creation; live updates retain the same player',
    () async {
      await controller.initialize();
      expect(platform.creationOptions, same(initial));
      const updated = VideoPlayerWebHlsOptions(
        maxForwardBufferDuration: Duration(seconds: 60),
        backBufferDuration: Duration(seconds: 15),
      );
      await controller.setWebOptions(updated);
      expect(platform.updatedOptions, same(updated));
      expect(platform.creationCount, 1);
    },
  );

  test('a pre-initialization change is included in creation', () async {
    const updated = VideoPlayerWebHlsOptions(
      maxForwardBufferDuration: Duration(seconds: 45),
    );
    await controller.setWebOptions(updated);
    await controller.initialize();
    expect(platform.creationOptions, same(updated));
    expect(platform.creationCount, 1);
  });
}

///
class _Platform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  VideoPlayerWebOptions? creationOptions;
  VideoPlayerWebOptions? updatedOptions;
  int creationCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    creationCount++;
    creationOptions = (options as VideoPlayerWebCreationOptions).webOptions;
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 10),
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;

  @override
  Future<void> setWebOptions(
    int playerId,
    VideoPlayerWebOptions options,
  ) async {
    updatedOptions = options;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> dispose(int playerId) async {}
}

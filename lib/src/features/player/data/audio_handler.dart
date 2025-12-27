import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Simple audio handler backed by just_audio.
class LessonAudioHandler extends BaseAudioHandler with SeekHandler {
  LessonAudioHandler(this._player) {
    _notifyAudioHandlerAboutPlaybackEvents();
  }

  final AudioPlayer _player;

  AudioPlayer get player => _player;

  Future<void> loadAsset(String assetPath) async {
    await _player.setAudioSource(AudioSource.asset(assetPath));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.rewind,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.fastForward,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: _transformProcessingState(_player.processingState),
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });
  }

  AudioProcessingState _transformProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}

Future<LessonAudioHandler> initAudioHandler() async {
  final handler = await AudioService.init(
    builder: () => LessonAudioHandler(AudioPlayer()),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.language.app.channel.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
    ),
  );
  return handler;
}


import 'package:audioplayers/audioplayers.dart';

/// BioGuard — Alarm Player
/// Plays the audible alarm for critical alerts.
/// Uses assets/sounds/alarm.wav.
class AlarmPlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> play() async {
    try {
      await _player.play(AssetSource('sounds/alarm.wav'));
    } catch (e) {
      print('[BioGuard] Failed to play alarm: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}

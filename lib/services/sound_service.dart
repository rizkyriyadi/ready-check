import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  final AudioPlayer _player = AudioPlayer();

  // Preload sounds if possible, or just play on demand for MVP
  // Ideally, use a pool for rapid sounds, but single player is fine for this app style.

  Future<void> playJoin() async {
    await _playSound('join.mp3');
  }

  Future<void> playReady() async {
    await _playSound('ready.mp3');
  }

  Future<void> playSummon() async {
    await _playSound('summon.mp3');
  }

  Future<void> _playSound(String fileName) async {
    try {
      // AudioPlayers assumes 'assets/' prefix if Source is removed? 
      // Starting from 6.0, use AssetSource('path/relative/to/assets')
      // Note: In pubspec we added assets/audio/
      // So AssetSource('audio/filename')
      
      await _player.stop(); // Stop previous sound to prevent overlap overlap mania
      await _player.play(AssetSource('audio/$fileName'), volume: 1.0);
    } catch (e) {
      debugPrint("Error playing sound $fileName: $e");
    }
  }
}

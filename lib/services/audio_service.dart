import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

/// 音声再生と音量設定を管理するサービス
class AudioService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const String _notificationSoundPathKey = 'notification_sound_path';
  static const String _volumeKey = 'notification_volume';

  String? _notificationSoundPath;
  double _volume = 1.0; // 0.0 to 1.0

  String? get notificationSoundPath => _notificationSoundPath;
  double get volume => _volume;

  AudioService() {
    _initAudioService();
  }

  /// AudioServiceを初期化し、保存された設定をロードする
  Future<void> _initAudioService() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationSoundPath = prefs.getString(_notificationSoundPathKey);
    _volume = prefs.getDouble(_volumeKey) ?? 1.0;
    _audioPlayer.setVolume(_volume);

    // デフォルトのサンプル音源を設定
    if (_notificationSoundPath == null || _notificationSoundPath!.isEmpty) {
      // アプリケーションのアセットからデフォルト音源を使用
      // これはビルド時にバンドルされるため、パスは 'asset:' スキームで指定する
      // 実際には、プロジェクトの pubspec.yaml に assets/sounds/notification.mp3 を追加する必要がある
      // 例: assets: - assets/sounds/notification.mp3
      // ここでは仮のパスを設定し、実際のファイルは提供しないため、動作確認時は注意
      _notificationSoundPath = 'assets/sounds/notification.mp3'; // 仮のパス
    }
    notifyListeners();
  }

  /// 通知音を再生する
  Future<void> playNotificationSound() async {
    if (_notificationSoundPath != null && _notificationSoundPath!.isNotEmpty) {
      try {
        if (_notificationSoundPath!.startsWith('asset:')) {
          await _audioPlayer.play(AssetSource(_notificationSoundPath!.substring(6)));
        } else {
          // ファイルパスの場合
          await _audioPlayer.play(DeviceFileSource(_notificationSoundPath!));
        }
      } catch (e) {
        debugPrint('通知音の再生に失敗しました: $e');
      }
    }
  }

  /// 音量を設定する
  Future<void> setVolume(double newVolume) async {
    _volume = newVolume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
    notifyListeners();
  }

  /// カスタム通知音ファイルを選択し、設定する
  Future<void> selectCustomNotificationSound() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final newPath = result.files.single.path!;
      _notificationSoundPath = newPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationSoundPathKey, newPath);
      notifyListeners();
      debugPrint('カスタム通知音が設定されました: $newPath');
    } else {
      debugPrint('カスタム通知音の選択がキャンセルされました。');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

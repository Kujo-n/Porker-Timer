import 'dart:async';
import 'package:flutter/material.dart';
import 'package:poker_timer_app/models/blind_level.dart'; // BlindLevelモデルのインポート
import 'package:poker_timer_app/models/tournament_settings.dart'; // TournamentSettingsモデルのインポート
import 'package:poker_timer_app/models/event_log_entry.dart'; // EventLogEntryモデルのインポート
import 'package:poker_timer_app/services/log_service.dart'; // LogServiceのインポート
import 'package:poker_timer_app/services/audio_service.dart'; // AudioServiceのインポート


/// タイマーロジックを管理するサービス
class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _currentLevelIndex = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  TournamentSettings? _currentSettings;

  /// 現在のブラインドレベルのインデックス
  int get currentLevelIndex => _currentLevelIndex;

  /// 残り時間（秒）
  int get remainingSeconds => _remainingSeconds;

  /// タイマーが実行中かどうか
  bool get isRunning => _isRunning;

  /// タイマーが一時停止中かどうか
  bool get isPaused => _isPaused;

  /// 現在のトーナメント設定
  TournamentSettings? get currentSettings => _currentSettings;

  /// 現在のブラインドレベル
  BlindLevel? get currentLevel {
    if (_currentSettings == null || _currentLevelIndex >= _currentSettings!.levels.length) {
      return null;
    }
    return _currentSettings!.levels[_currentLevelIndex];
  }

  /// 次のブラインドレベル
  BlindLevel? get nextLevel {
    if (_currentSettings == null || _currentLevelIndex + 1 >= _currentSettings!.levels.length) {
      return null;
    }
    return _currentSettings!.levels[_currentLevelIndex + 1];
  }

  /// タイマーを初期化し、設定をロードする
  void initializeTimer(TournamentSettings settings) {
    _currentSettings = settings;
    _currentLevelIndex = 0;
    if (_currentSettings != null && _currentSettings!.levels.isNotEmpty) {
      _remainingSeconds = _currentSettings!.levels[0].durationMinutes * 60;
    } else {
      _remainingSeconds = 0;
    }
    _isRunning = false;
    _isPaused = false;
    _timer?.cancel();
    notifyListeners();
  }

  /// タイマーを開始する
  void startTimer(LogService logService, AudioService audioService) {
    if (_isRunning) return;
    if (_currentSettings == null || _currentSettings!.levels.isEmpty) {
      logService.addLog(EventLogEntry(
          timestamp: DateTime.now(),
          eventType: 'TimerOperation',
          description: 'タイマー開始失敗: 設定がありません'));
      return;
    }

    _isRunning = true;
    _isPaused = false;
    _startCountdown(logService, audioService);
    logService.addLog(EventLogEntry(
        timestamp: DateTime.now(),
        eventType: 'TimerOperation',
        description: 'タイマーが開始されました。残り時間: ${formatDuration(_remainingSeconds)}'));
    notifyListeners();
  }

  /// タイマーを一時停止する
  void pauseTimer(LogService logService) {
    if (!_isRunning) return;
    _timer?.cancel();
    _isPaused = true;
    _isRunning = false; // 一時停止中は実行中ではないとみなす
    logService.addLog(EventLogEntry(
        timestamp: DateTime.now(),
        eventType: 'TimerOperation',
        description: 'タイマーが一時停止されました。残り時間: ${formatDuration(_remainingSeconds)}'));
    notifyListeners();
  }

  /// タイマーを再開する
  void resumeTimer(LogService logService, AudioService audioService) {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;
    _startCountdown(logService, audioService);
    logService.addLog(EventLogEntry(
        timestamp: DateTime.now(),
        eventType: 'TimerOperation',
        description: 'タイマーが再開されました。残り時間: ${formatDuration(_remainingSeconds)}'));
    notifyListeners();
  }

  /// タイマーをリセットする
  void resetTimer(LogService logService) {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _currentLevelIndex = 0;
    if (_currentSettings != null && _currentSettings!.levels.isNotEmpty) {
      _remainingSeconds = _currentSettings!.levels[0].durationMinutes * 60;
    } else {
      _remainingSeconds = 0;
    }
    logService.addLog(EventLogEntry(
        timestamp: DateTime.now(),
        eventType: 'TimerOperation',
        description: 'タイマーがリセットされました。'));
    notifyListeners();
  }

  /// 現在のレベルをスキップし、次のレベルへ移行する
  void skipLevel(LogService logService, AudioService audioService) {
    _timer?.cancel();
    logService.addLog(EventLogEntry(
        timestamp: DateTime.now(),
        eventType: 'LevelSkip',
        description:
            '現在のブラインドレベルがスキップされ、次のレベルに移行しました。'));
    _moveToNextLevel(logService, audioService);
    if (_isRunning) {
      _startCountdown(logService, audioService);
    }
    notifyListeners();
  }

  /// カウントダウンを開始する内部メソッド
  void _startCountdown(LogService logService, AudioService audioService) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
      } else {
        _timer?.cancel();
        _moveToNextLevel(logService, audioService);
        if (_isRunning) {
          _startCountdown(logService, audioService);
        }
      }
      notifyListeners();
    });
  }

  /// 次のレベルへ移行する内部メソッド
  void _moveToNextLevel(LogService logService, AudioService audioService) {
    if (_currentSettings == null) return;

    if (_currentLevelIndex + 1 < _currentSettings!.levels.length) {
      _currentLevelIndex++;
      final newLevel = _currentSettings!.levels[_currentLevelIndex];
      _remainingSeconds = newLevel.durationMinutes * 60;

      String eventDescription;
      if (newLevel.isBreak) {
        audioService.playNotificationSound();
        eventDescription = '休憩が始まりました。休憩時間: ${newLevel.durationMinutes}分';
        logService.addLog(EventLogEntry(
            timestamp: DateTime.now(),
            eventType: 'BreakStart',
            description: eventDescription));
      } else {
        audioService.playNotificationSound();
        eventDescription =
            'ブラインドレベルがSmall Blind: ${newLevel.smallBlind}, Big Blind: ${newLevel.bigBlind}, Ante: ${newLevel.ante} に上がりました。';
        logService.addLog(EventLogEntry(
            timestamp: DateTime.now(),
            eventType: 'BlindLevelChange',
            description: eventDescription));
      }
    } else {
      // 全てのレベルが終了
      _isRunning = false;
      _isPaused = false;
      _remainingSeconds = 0;
      logService.addLog(EventLogEntry(
          timestamp: DateTime.now(),
          eventType: 'TournamentEnd',
          description: 'トーナメントが終了しました。'));
    }
    notifyListeners();
  }

  /// 時間を "MM:SS" 形式にフォーマットするユーティリティ
  String formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

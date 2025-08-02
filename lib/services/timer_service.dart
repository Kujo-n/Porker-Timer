import 'dart:async';
import 'package:flutter/material.dart';
import 'package:poker_timer_app/models/blind_level.dart'; // BlindLevelモデルのインポート
import 'package:poker_timer_app/models/tournament_settings.dart'; // TournamentSettingsモデルのインポート
import 'package:poker_timer_app/models/event_log_entry.dart'; // EventLogEntryモデルのインポート
import 'package:poker_timer_app/services/log_service.dart'; // LogServiceのインポート
import 'package:poker_timer_app/services/audio_service.dart'; // AudioServiceのインポート
import 'package:poker_timer_app/services/settings_service.dart'; // SettingsServiceのインポート


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

  // TimerServiceの初期化（設定ロードを含む）
  Future<void> init(SettingsService settingsService) async {
    // 既に設定がロードされている場合は何もしない (二重初期化防止)
    if (_currentSettings != null) {
      return;
    }

    TournamentSettings? initialSettings;
    const String defaultSettingName = 'Default-Tabel';

    // SettingsServiceの非同期初期化が完了するのを待つ
    await settingsService.initializationComplete;

    // 1. 最後に使用された設定をロードしようと試みる
    final lastUsedSettingName = settingsService.loadLastUsedSettingName();
    if (lastUsedSettingName != null) {
      initialSettings = await settingsService.loadSettings(lastUsedSettingName);
      if (initialSettings != null) {
        debugPrint('最後に使用された設定 "${lastUsedSettingName}" をロードしました。');
      } else {
        debugPrint('最後に使用された設定ファイルが見つからないか、ロードに失敗しました: $lastUsedSettingName');
      }
    }

    // 2. 最後に使用された設定がロードできなかった場合、デフォルト設定をロードしようと試みる
    if (initialSettings == null && settingsService.savedSettingNames.contains(defaultSettingName)) {
      initialSettings = await settingsService.loadSettings(defaultSettingName);
      if (initialSettings != null) {
        debugPrint('デフォルト設定 "${defaultSettingName}" をロードしました。');
      } else {
        debugPrint('デフォルト設定ファイルが見つからないか、ロードに失敗しました: $defaultSettingName');
      }
    }

    // 3. どの設定もロードできなかった場合、基本的な新規設定を作成
    if (initialSettings == null) {
      initialSettings = TournamentSettings(name: '新規設定', levels: []);
      // 空のレベルリストの場合、初期レベルを一つ追加
      if (initialSettings.levels.isEmpty) {
        initialSettings.levels.add(BlindLevel(id: UniqueKey().toString(), smallBlind: 100, bigBlind: 200, ante: 0, durationMinutes: 15));
      }
      debugPrint('新しい空の設定を作成しました。');
    }

    // 決定した設定でTimerServiceを初期化
    initializeTimer(initialSettings);
    // 最後にロードされた設定名を保存（新規作成された場合も含む）
    await settingsService.saveLastUsedSettingName(initialSettings.name);
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

  /// タイマーをリセットする (トーナメント全体のリセット)
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

  /// 現在のレベルの時間をリセットする (ブラインドリセット)
  void resetCurrentLevelTime(LogService logService, AudioService audioService) { // audioServiceを追加
    if (_currentSettings == null || _currentSettings!.levels.isEmpty) {
      logService.addLog(EventLogEntry(
          timestamp: DateTime.now(),
          eventType: 'BlindResetFailed',
          description: 'ブラインドリセット失敗: 設定がありません。'));
      return;
    }
    if (_currentLevelIndex < _currentSettings!.levels.length) {
      _remainingSeconds = _currentSettings!.levels[_currentLevelIndex].durationMinutes * 60;
      logService.addLog(EventLogEntry(
          timestamp: DateTime.now(),
          eventType: 'BlindReset',
          description: '現在のブラインドレベルの時間がリセットされました。残り時間: ${formatDuration(_remainingSeconds)}'));
      // タイマーが実行中であれば、時間をリセットした後に再開
      if (_isRunning) {
        _startCountdown(logService, audioService);
      }
      notifyListeners();
    } else {
      logService.addLog(EventLogEntry(
          timestamp: DateTime.now(),
          eventType: 'BlindResetFailed',
          description: 'ブラインドリセット失敗: 無効なレベルインデックスです。'));
    }
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

  /// 1つ前のブラインドレベルに戻る
  void previousLevel(LogService logService, AudioService audioService) {
    if (_currentLevelIndex > 0) {
      _timer?.cancel(); // 現在のタイマーを停止
      _currentLevelIndex--; // インデックスを1つ戻す
      final prevLevel = _currentSettings!.levels[_currentLevelIndex];
      _remainingSeconds = prevLevel.durationMinutes * 60; // 以前のレベルの時間に設定

      logService.addLog(EventLogEntry(
          timestamp: DateTime.now(),
          eventType: 'LevelBack',
          description:
              '1つ前のブラインドレベルに戻りました。レベル: ${prevLevel.isBreak ? "休憩" : (currentLevelIndex + 1)}, 残り時間: ${formatDuration(_remainingSeconds)}'));

      // タイマーが実行中だった場合は再開
      if (_isRunning) {
        _startCountdown(logService, audioService);
      }
      notifyListeners();
    } else {
      logService.addLog(EventLogEntry(
          timestamp: DateTime.now(),
          eventType: 'LevelBackFailed',
          description: 'これ以上前のブラインドレベルはありません。'));
    }
  }

  /// カウントダウンを開始する内部メソッド
  void _startCountdown(LogService logService, AudioService audioService) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
      } else {
        _timer?.cancel();
        // ★ ここで音声再生（タイマーが0になった瞬間のみ）
        final nextLevelValue = nextLevel; // ←変数名を変更
        if (nextLevelValue != null) {
          if (nextLevelValue.isBreak) {
            audioService.playNotificationSound();
          } else {
            audioService.playNotificationSound();
          }
        }
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
        eventDescription = '休憩が始まりました。休憩時間: ${newLevel.durationMinutes}分';
        logService.addLog(EventLogEntry(
            timestamp: DateTime.now(),
            eventType: 'BreakStart',
            description: eventDescription));
      } else {
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

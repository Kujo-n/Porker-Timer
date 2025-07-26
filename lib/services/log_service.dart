import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:poker_timer_app/models/event_log_entry.dart'; // EventLogEntryモデルのインポート

/// イベントログを管理するサービス
class LogService extends ChangeNotifier {
  static const String _logFileName = 'poker_timer_log.csv';
  static const int _maxLogEntries = 30;

  List<EventLogEntry> _logs = [];
  bool _isInitialized = false;

  List<EventLogEntry> get logs => _logs;

  LogService() {
    _initLogService();
  }

  /// ログサービスを初期化し、既存のログをロードする
  Future<void> _initLogService() async {
    await _loadLogs();
    _isInitialized = true;
    notifyListeners();
  }

  /// ログファイルへのパスを取得する
  Future<String> _getLogFilePath() async {
    final directory = await getApplicationSupportDirectory(); // アプリケーションのデータフォルダ
    final logDirectory = Directory('${directory.path}/logs');
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }
    return '${logDirectory.path}/$_logFileName';
  }

  /// ログをファイルからロードする
  Future<void> _loadLogs() async {
    try {
      final filePath = await _getLogFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        _logs = lines.map((line) {
          final parts = line.split(',');
          return EventLogEntry.fromCsvRow(parts);
        }).toList();
        // 最新30件にトリミング
        if (_logs.length > _maxLogEntries) {
          _logs = _logs.sublist(_logs.length - _maxLogEntries);
        }
      }
    } catch (e) {
      debugPrint('ログの読み込みに失敗しました: $e');
      _logs = [];
    }
  }

  /// ログをファイルに保存する
  Future<void> _saveLogs() async {
    try {
      final filePath = await _getLogFilePath();
      final file = File(filePath);
      // 最新30件にトリミングしてから保存
      List<EventLogEntry> logsToSave = _logs;
      if (logsToSave.length > _maxLogEntries) {
        logsToSave = logsToSave.sublist(logsToSave.length - _maxLogEntries);
      }
      final lines = logsToSave.map((entry) => entry.toCsvRow().join(',')).toList();
      await file.writeAsString(lines.join('\n'));
    } catch (e) {
      debugPrint('ログの保存に失敗しました: $e');
    }
  }

  /// 新しいログエントリを追加する
  Future<void> addLog(EventLogEntry entry) async {
    _logs.add(entry);
    if (_logs.length > _maxLogEntries) {
      _logs.removeAt(0); // 最も古いエントリを削除
    }
    await _saveLogs();
    notifyListeners();
  }

  /// ログをクリアする (開発/デバッグ用)
  Future<void> clearLogs() async {
    _logs.clear();
    await _saveLogs(); // ファイルも空にする
    notifyListeners();
  }
}

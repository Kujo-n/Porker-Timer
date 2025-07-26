import 'package:intl/intl.dart'; // 日付フォーマット用

/// イベントログのエントリを保持するモデル
class EventLogEntry {
  DateTime timestamp; // イベント発生日時
  String eventType; // イベントタイプ (例: 'BlindLevelChange', 'BreakStart')
  String description; // イベントの詳細

  EventLogEntry({
    required this.timestamp,
    required this.eventType,
    required this.description,
  });

  /// CSV行からEventLogEntryオブジェクトを生成するファクトリコンストラクタ
  factory EventLogEntry.fromCsvRow(List<String> row) {
    return EventLogEntry(
      timestamp: DateTime.parse(row[0]),
      eventType: row[1],
      description: row[2],
    );
  }

  /// EventLogEntryオブジェクトをCSV行に変換するメソッド
  List<String> toCsvRow() {
    return [
      timestamp.toIso8601String(),
      eventType,
      description,
    ];
  }

  /// 表示用のフォーマットされたタイムスタンプを返す
  String get formattedTimestamp =>
      DateFormat('yyyy/MM/dd HH:mm:ss').format(timestamp);
}

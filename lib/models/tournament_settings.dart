import 'package:poker_timer_app/models/blind_level.dart'; // BlindLevelモデルのインポート

/// トーナメント設定全体を保持するモデル
class TournamentSettings {
  String name; // 設定の名前
  List<BlindLevel> levels; // ブラインドレベルのリスト

  TournamentSettings({
    required this.name,
    required this.levels,
  });

  /// JSONからTournamentSettingsオブジェクトを生成するファクトリコンストラクタ
  factory TournamentSettings.fromJson(Map<String, dynamic> json) {
    var levelsFromJson = json['levels'] as List;
    List<BlindLevel> levelsList = levelsFromJson
        .map((levelJson) => BlindLevel.fromJson(levelJson))
        .toList();

    return TournamentSettings(
      name: json['name'],
      levels: levelsList,
    );
  }

  /// TournamentSettingsオブジェクトをJSONに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'levels': levels.map((level) => level.toJson()).toList(),
    };
  }
}

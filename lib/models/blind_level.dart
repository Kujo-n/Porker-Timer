/// ブラインドレベルの情報を保持するモデル
class BlindLevel {
  String id; // 各ブラインドレベルを一意に識別するためのID
  int smallBlind;
  int bigBlind;
  int ante;
  int durationMinutes; // このレベルの継続時間（分）
  bool isBreak; // 休憩レベルかどうか

  BlindLevel({
    required this.id,
    required this.smallBlind,
    required this.bigBlind,
    required this.ante,
    required this.durationMinutes,
    this.isBreak = false,
  });

  /// JSONからBlindLevelオブジェクトを生成するファクトリコンストラクタ
  factory BlindLevel.fromJson(Map<String, dynamic> json) {
    return BlindLevel(
      id: json['id'],
      smallBlind: json['smallBlind'],
      bigBlind: json['bigBlind'],
      ante: json['ante'],
      durationMinutes: json['durationMinutes'],
      isBreak: json['isBreak'] ?? false,
    );
  }

  /// BlindLevelオブジェクトをJSONに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'smallBlind': smallBlind,
      'bigBlind': bigBlind,
      'ante': ante,
      'durationMinutes': durationMinutes,
      'isBreak': isBreak,
    };
  }
}

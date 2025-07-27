import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; // ファイルパス取得用
import 'dart:convert'; // JSONエンコード/デコード用
import 'dart:io'; // ファイル操作用
import 'package:flutter/services.dart' show rootBundle; // アセット読み込み用
import 'package:shared_preferences/shared_preferences.dart'; // 最後に使用された設定名保存用
import 'package:poker_timer_app/models/tournament_settings.dart'; // TournamentSettingsモデルのインポート
import 'package:poker_timer_app/models/blind_level.dart'; // BlindLevelモデルのインポート (TournamentSettingsが依存するため)

/// 設定の保存と読み込みを管理するサービス
class SettingsService extends ChangeNotifier {
  static const String _settingsDirectoryName = 'tournament_settings';
  static const String _fileExtension = '.json';
  static const String _defaultSettingsFileName = 'Default-Tabel.json';
  static const String _defaultSettingsAssetPath = 'assets/default_settings/Default-Tabel.json';
  static const String _lastUsedSettingKey = 'last_used_tournament_setting'; // 最後に使用された設定名のキー

  List<String> _savedSettingNames = [];
  late Future<void> _initializationFuture; // 初期化完了を待機するためのFuture
  late SharedPreferences _prefs; // SharedPreferencesインスタンス

  List<String> get savedSettingNames => _savedSettingNames;

  SettingsService() {
    _initializationFuture = _init(); // コンストラクタで非同期初期化を開始
  }

  /// SettingsServiceの非同期初期化処理
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance(); // SharedPreferencesを初期化
    await _loadSavedSettingNames(); // まず既存の設定名をロード

    // デフォルト設定ファイルが保存済み設定リストにない場合、アセットからコピーして保存
    if (!_savedSettingNames.contains(_defaultSettingsFileName.replaceAll(_fileExtension, ''))) {
      await _copyDefaultSettingsAsset();
      // デフォルト設定をコピーした後、再度保存済み設定名をロードしてリストを更新
      await _loadSavedSettingNames();
    }
    notifyListeners(); // 初期化完了をリスナーに通知
  }

  /// SettingsServiceの初期化が完了するFutureを返す
  Future<void> get initializationComplete => _initializationFuture;

  /// 設定ファイルを保存するディレクトリのパスを取得する
  Future<Directory> _getSettingsDirectory() async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    final settingsDirectory = Directory('${appSupportDirectory.path}/$_settingsDirectoryName');
    if (!await settingsDirectory.exists()) {
      await settingsDirectory.create(recursive: true);
    }
    return settingsDirectory;
  }

  /// 指定された設定名に対応するファイルのパスを取得する
  Future<File> _getSettingFile(String name) async {
    final directory = await _getSettingsDirectory();
    return File('${directory.path}/$name$_fileExtension');
  }

  /// 保存されている設定の名前リストをファイルシステムからロードする
  Future<void> _loadSavedSettingNames() async {
    try {
      final directory = await _getSettingsDirectory();
      final files = directory.listSync().whereType<File>().toList();
      _savedSettingNames = files
          .where((file) => file.path.endsWith(_fileExtension))
          .map((file) => file.path.split(Platform.pathSeparator).last.replaceAll(_fileExtension, ''))
          .toList();
      // ここではnotifyListenersは呼ばない。_init()またはsave/deleteでまとめて呼ぶため。
    } catch (e) {
      debugPrint('設定名のロードに失敗しました: $e');
      _savedSettingNames = [];
    }
  }

  /// アセットからデフォルト設定ファイルをコピーして保存する
  Future<void> _copyDefaultSettingsAsset() async {
    try {
      final String jsonString = await rootBundle.loadString(_defaultSettingsAssetPath);
      final defaultSettings = TournamentSettings.fromJson(jsonDecode(jsonString));
      await saveSettings(defaultSettings); // デフォルト設定をファイルとして保存
      debugPrint('デフォルト設定がコピーされました: ${_defaultSettingsFileName}');
    } catch (e) {
      debugPrint('デフォルト設定のコピーに失敗しました: $e');
    }
  }

  /// トーナメント設定をJSONファイルとして保存する
  Future<void> saveSettings(TournamentSettings settings) async {
    try {
      final file = await _getSettingFile(settings.name);
      final String jsonString = jsonEncode(settings.toJson());
      await file.writeAsString(jsonString);
      await _loadSavedSettingNames(); // 保存後にリストを更新
      await saveLastUsedSettingName(settings.name); // 最後に使用された設定として記録
      debugPrint('設定 "${settings.name}" がファイルに保存されました: ${file.path}');
    } catch (e) {
      debugPrint('設定の保存に失敗しました: $e');
    }
  }

  /// トーナメント設定をJSONファイルから読み込む
  Future<TournamentSettings?> loadSettings(String name) async {
    try {
      final file = await _getSettingFile(name);
      if (await file.exists()) {
        final String jsonString = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        debugPrint('設定 "${name}" がファイルからロードされました: ${file.path}');
        await saveLastUsedSettingName(name); // 最後に使用された設定として記録
        return TournamentSettings.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint('設定の読み込みに失敗しました: $e');
    }
    return null;
  }

  /// トーナメント設定のJSONファイルを削除する
  Future<void> deleteSettings(String name) async {
    try {
      final file = await _getSettingFile(name);
      if (await file.exists()) {
        await file.delete();
        await _loadSavedSettingNames(); // 削除後にリストを更新
        // 削除した設定が最後に使用された設定だった場合、記録をクリア
        if (loadLastUsedSettingName() == name) {
          await _prefs.remove(_lastUsedSettingKey);
        }
        debugPrint('設定 "${name}" がファイルから削除されました: ${file.path}');
      }
    } catch (e) {
      debugPrint('設定の削除に失敗しました: $e');
    }
  }

  /// 最後に使用された設定名を保存する
  Future<void> saveLastUsedSettingName(String name) async {
    await _prefs.setString(_lastUsedSettingKey, name);
    debugPrint('最後に使用された設定: $name');
  }

  /// 最後に使用された設定名を読み込む
  String? loadLastUsedSettingName() {
    return _prefs.getString(_lastUsedSettingKey);
  }
}

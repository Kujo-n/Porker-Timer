import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; // ファイルパス取得用
import 'dart:convert'; // JSONエンコード/デコード用
import 'dart:io'; // ファイル操作用
import 'package:poker_timer_app/models/tournament_settings.dart'; // TournamentSettingsモデルのインポート
import 'package:poker_timer_app/models/blind_level.dart'; // BlindLevelモデルのインポート (TournamentSettingsが依存するため)

/// 設定の保存と読み込みを管理するサービス
class SettingsService extends ChangeNotifier {
  static const String _settingsDirectoryName = 'tournament_settings';
  static const String _fileExtension = '.json';

  List<String> _savedSettingNames = [];

  List<String> get savedSettingNames => _savedSettingNames;

  SettingsService() {
    _initSettingsService();
  }

  /// SettingsServiceを初期化し、既存の設定ファイル名をロードする
  Future<void> _initSettingsService() async {
    await _loadSavedSettingNames();
  }

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
      notifyListeners();
    } catch (e) {
      debugPrint('設定名のロードに失敗しました: $e');
      _savedSettingNames = [];
    }
  }

  /// トーナメント設定をJSONファイルとして保存する
  Future<void> saveSettings(TournamentSettings settings) async {
    try {
      final file = await _getSettingFile(settings.name);
      final String jsonString = jsonEncode(settings.toJson());
      await file.writeAsString(jsonString);
      await _loadSavedSettingNames(); // 保存後にリストを更新
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
        debugPrint('設定 "${name}" がファイルから削除されました: ${file.path}');
      }
    } catch (e) {
      debugPrint('設定の削除に失敗しました: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:poker_timer_app/models/tournament_settings.dart'; // TournamentSettingsモデルのインポート

/// 設定の保存と読み込みを管理するサービス
class SettingsService extends ChangeNotifier {
  static const String _settingsKeyPrefix = 'poker_timer_settings_';
  static const String _savedSettingsListKey = 'saved_poker_timer_settings_list';
  late SharedPreferences _prefs;

  List<String> _savedSettingNames = [];

  List<String> get savedSettingNames => _savedSettingNames;

  SettingsService() {
    _initPrefs();
  }

  /// SharedPreferencesを初期化する
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSavedSettingNames();
  }

  /// 保存されている設定の名前リストをロードする
  void _loadSavedSettingNames() {
    _savedSettingNames = _prefs.getStringList(_savedSettingsListKey) ?? [];
    notifyListeners();
  }

  /// トーナメント設定を保存する
  Future<void> saveSettings(TournamentSettings settings) async {
    final String jsonString = jsonEncode(settings.toJson());
    await _prefs.setString('$_settingsKeyPrefix${settings.name}', jsonString);
    if (!_savedSettingNames.contains(settings.name)) {
      _savedSettingNames.add(settings.name);
      await _prefs.setStringList(_savedSettingsListKey, _savedSettingNames);
    }
    notifyListeners();
  }

  /// トーナメント設定を読み込む
  Future<TournamentSettings?> loadSettings(String name) async {
    final String? jsonString =
        _prefs.getString('$_settingsKeyPrefix$name');
    if (jsonString != null) {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return TournamentSettings.fromJson(jsonMap);
    }
    return null;
  }

  /// トーナメント設定を削除する
  Future<void> deleteSettings(String name) async {
    await _prefs.remove('$_settingsKeyPrefix$name');
    _savedSettingNames.remove(name);
    await _prefs.setStringList(_savedSettingsListKey, _savedSettingNames);
    notifyListeners();
  }
}

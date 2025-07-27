import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:poker_timer_app/models/blind_level.dart'; // BlindLevelモデルのインポート
import 'package:poker_timer_app/models/tournament_settings.dart'; // TournamentSettingsモデルのインポート
import 'package:poker_timer_app/services/settings_service.dart'; // SettingsServiceのインポート
import 'package:poker_timer_app/services/timer_service.dart'; // TimerServiceのインポート
import 'package:poker_timer_app/services/audio_service.dart'; // AudioServiceのインポート

/// トーナメント設定画面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tournamentNameController = TextEditingController();
  List<BlindLevel> _currentLevels = [];
  String? _originalSettingName; // ロードされた設定の元の名前を保持

  @override
  void initState() {
    super.initState();
    // 設定画面を開いた際に、現在の設定名と設定内容を表示
    // TimerServiceが初期化されるのを待つため、WidgetsBinding.instance.addPostFrameCallbackを使用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timerService = Provider.of<TimerService>(context, listen: false);
      if (timerService.currentSettings != null) {
        setState(() {
          _tournamentNameController.text = timerService.currentSettings!.name;
          _currentLevels = List.from(timerService.currentSettings!.levels); // ディープコピー
          _originalSettingName = timerService.currentSettings!.name; // 元の名前を保存
        });
      } else {
        // 設定がロードされていない場合は初期表示用に1つ追加
        _addBlindLevel();
      }
    });
  }

  /// ブラインドレベルを追加する
  void _addBlindLevel({bool isBreak = false}) {
    setState(() {
      _currentLevels.add(BlindLevel(
        id: UniqueKey().toString(), // ユニークなIDを生成
        smallBlind: isBreak ? 0 : 100,
        bigBlind: isBreak ? 0 : 200,
        ante: isBreak ? 0 : 0,
        durationMinutes: isBreak ? 10 : 15,
        isBreak: isBreak,
      ));
    });
  }

  /// ブラインドレベルを削除する
  void _deleteBlindLevel(String id) {
    setState(() {
      _currentLevels.removeWhere((level) => level.id == id);
    });
  }

  /// 設定を保存する
  Future<void> _saveTournamentSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final timerService = Provider.of<TimerService>(context, listen: false);

      final newSettings = TournamentSettings(
        name: _tournamentNameController.text,
        levels: _currentLevels,
      );

      // 元の名前と現在の名前が異なる場合、元の設定を削除して新しい名前で保存（別名保存）
      // 同じ名前の場合は上書き保存
      if (_originalSettingName != null && _originalSettingName != newSettings.name) {
        await settingsService.deleteSettings(_originalSettingName!);
      }

      await settingsService.saveSettings(newSettings);

      // 保存した設定をタイマーにロード
      timerService.initializeTimer(newSettings);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newSettings.name} が保存されました。')),
      );
      Navigator.pop(context);
    }
  }

  /// 既存の設定をロードするダイアログを表示
  Future<void> _showLoadSettingsDialog() async {
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final selectedSettingName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('設定をロード'),
          content: settingsService.savedSettingNames.isEmpty
              ? const Text('保存された設定がありません。')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: settingsService.savedSettingNames.length,
                    itemBuilder: (context, index) {
                      final settingName = settingsService.savedSettingNames[index];
                      return ListTile(
                        title: Text(settingName),
                        onTap: () {
                          Navigator.pop(dialogContext, settingName);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            final confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext ctx) => AlertDialog(
                                title: const Text('確認'),
                                content: Text('本当に "$settingName" を削除しますか？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('削除'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmDelete == true) {
                              await settingsService.deleteSettings(settingName);
                              // ダイアログを閉じて再表示するか、StatefulBuilderで更新
                              Navigator.pop(dialogContext); // 現在のダイアログを閉じる
                              _showLoadSettingsDialog(); // 再度ダイアログを開く
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
          ],
        );
      },
    );

    if (selectedSettingName != null) {
      final loadedSettings =
          await settingsService.loadSettings(selectedSettingName);
      if (loadedSettings != null) {
        setState(() {
          _tournamentNameController.text = loadedSettings.name;
          _currentLevels = List.from(loadedSettings.levels); // ディープコピー
          _originalSettingName = loadedSettings.name; // 元の名前を保存
        });
        Provider.of<TimerService>(context, listen: false).initializeTimer(loadedSettings);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${loadedSettings.name}" がロードされました。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('トーナメント設定', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.white),
            onPressed: _showLoadSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveTournamentSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _tournamentNameController,
                decoration: const InputDecoration(
                  labelText: '設定名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '設定名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // テーブルヘッダー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: const [
                    SizedBox(width: 40, child: Text('Lv', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('時間(分)', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('SB', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('BB', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Ante', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(width: 48), // 削除ボタンのスペース
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _currentLevels.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = _currentLevels.removeAt(oldIndex);
                      _currentLevels.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final level = _currentLevels[index];
                    return Card(
                      key: ValueKey(level.id), // ReorderableListViewにはkeyが必須
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          children: [
                            // ブラインドレベル番号/Break表示
                            SizedBox(
                              width: 40,
                              child: Text(
                                level.isBreak ? 'Break' : '${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            // 継続時間
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: level.durationMinutes.toString(),
                                decoration: const InputDecoration(
                                  isDense: true, // 高さを詰める
                                  contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || int.tryParse(value) == null || int.parse(value!) <= 0) {
                                    return ''; // エラーメッセージは簡潔に
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  level.durationMinutes = int.parse(value!);
                                },
                              ),
                            ),
                            // Small Blind, Big Blind, Ante
                            if (!level.isBreak) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: level.smallBlind.toString(),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || int.tryParse(value) == null || int.parse(value!) < 0) {
                                      return '';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {
                                    level.smallBlind = int.parse(value!);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: level.bigBlind.toString(),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || int.tryParse(value) == null || int.parse(value!) < 0) {
                                      return '';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {
                                    level.bigBlind = int.parse(value!);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: level.ante.toString(),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || int.tryParse(value) == null || int.parse(value!) < 0) {
                                      return '';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {
                                    level.ante = int.parse(value!);
                                  },
                                ),
                              ),
                            ] else ...[
                              // 休憩レベルの場合はSB, BB, Anteの入力フィールドを非表示にする
                              const Expanded(flex: 2, child: SizedBox()),
                              const SizedBox(width: 8),
                              const Expanded(flex: 2, child: SizedBox()),
                              const SizedBox(width: 8),
                              const Expanded(flex: 2, child: SizedBox()),
                            ],
                            // 削除ボタン
                            SizedBox(
                              width: 48,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteBlindLevel(level.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _addBlindLevel(isBreak: false),
                    icon: const Icon(Icons.add),
                    label: const Text('ブラインドレベル追加'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addBlindLevel(isBreak: true),
                    icon: const Icon(Icons.free_breakfast),
                    label: const Text('休憩レベル追加'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 通知音設定
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '通知音設定',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '現在の通知音: ${audioService.notificationSoundPath?.split('/').last ?? '未設定'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => audioService.selectCustomNotificationSound(),
                            child: const Text('通知音を選択'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('音量: '),
                          Expanded(
                            child: Slider(
                              value: audioService.volume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              label: (audioService.volume * 100).round().toString(),
                              onChanged: (newValue) {
                                audioService.setVolume(newValue);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up),
                            onPressed: () => audioService.playNotificationSound(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

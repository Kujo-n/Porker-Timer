import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _isEditingExisting = false;
  String? _originalSettingName;

  @override
  void initState() {
    super.initState();
    // 新規作成時は空のリストから開始
    _currentLevels = [];
    _addBlindLevel(); // 初期表示用に1つ追加
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
          _currentLevels = loadedSettings.levels;
          _isEditingExisting = true;
          _originalSettingName = loadedSettings.name;
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
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  level.isBreak ? '休憩レベル' : 'レベル ${index + 1}',
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteBlindLevel(level.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              initialValue: level.durationMinutes.toString(),
                              decoration: InputDecoration(
                                labelText: level.isBreak
                                    ? '休憩時間 (分)'
                                    : '継続時間 (分)',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || int.tryParse(value) == null) {
                                  return '有効な時間を入力してください';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                level.durationMinutes = int.parse(value!);
                              },
                            ),
                            if (!level.isBreak) ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                initialValue: level.smallBlind.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Small Blind',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || int.tryParse(value) == null) {
                                    return '有効な値を入力してください';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  level.smallBlind = int.parse(value!);
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                initialValue: level.bigBlind.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Big Blind',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || int.tryParse(value) == null) {
                                    return '有効な値を入力してください';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  level.bigBlind = int.parse(value!);
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                initialValue: level.ante.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Ante',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || int.tryParse(value) == null) {
                                    return '有効な値を入力してください';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  level.ante = int.parse(value!);
                                },
                              ),
                            ],
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

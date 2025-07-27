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

  // 各BlindLevelの各フィールドに対応するTextEditingControllerを管理するマップ
  final Map<String, TextEditingController> _durationControllers = {};
  final Map<String, TextEditingController> _sbControllers = {};
  final Map<String, TextEditingController> _bbControllers = {};
  final Map<String, TextEditingController> _anteControllers = {};

  List<BlindLevel> _currentLevels = [];
  String? _originalSettingName; // ロードされた設定の元の名前を保持

  @override
  void initState() {
    super.initState();
    // 設定画面を開いた際に、現在のタイマー設定を反映する
    // TimerServiceがmain.dartで既に初期化されていることを期待する
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final timerService = Provider.of<TimerService>(context, listen: false);
      final settingsService = Provider.of<SettingsService>(context, listen: false);

      // SettingsServiceの非同期初期化が完了するのを待つ
      await settingsService.initializationComplete;

      TournamentSettings? loadedSettings;

      // 1. TimerServiceに現在の設定がロードされているか確認
      if (timerService.currentSettings != null) {
        loadedSettings = timerService.currentSettings;
      } else {
        // 2. TimerServiceに設定がない場合、保存されたデフォルト設定または最初の保存済み設定をロード
        const String defaultSettingName = 'Default-Tabel'; // デフォルト設定ファイルの名前（拡張子なし）

        if (settingsService.savedSettingNames.contains(defaultSettingName)) {
          // デフォルト設定が保存されている場合、それをロード
          loadedSettings = await settingsService.loadSettings(defaultSettingName);
        } else if (settingsService.savedSettingNames.isNotEmpty) {
          // デフォルト設定がないが、他の保存済み設定がある場合、最初のものをロード
          loadedSettings = await settingsService.loadSettings(settingsService.savedSettingNames.first);
        }
      }

      // 3. どの設定もロードできなかった場合、新規のデフォルト設定を作成
      if (loadedSettings == null) {
        loadedSettings = TournamentSettings(name: '新規設定', levels: []); // 初期は空のレベルリスト
      }

      // UIを更新
      setState(() {
        // loadedSettingsはここで非nullであることが保証される
        _tournamentNameController.text = loadedSettings!.name;
        _currentLevels = List.from(loadedSettings.levels); // ディープコピー
        _originalSettingName = loadedSettings.name;
        _initControllers(); // コントローラーを初期化
      });

      // TimerServiceに、現在UIに表示されている設定を初期化する
      timerService.initializeTimer(loadedSettings!);

      // もしロードされた設定（または新規作成された設定）にレベルが一つもなければ、初期レベルを一つ追加
      if (_currentLevels.isEmpty) {
        _addBlindLevel();
      }

      // もし設定名が「新規設定」で、それが保存されたものではない場合、_originalSettingNameをnullにする
      // これにより、「新規設定」として保存しようとした際に別名保存ではなく新規保存となる
      if (_tournamentNameController.text == '新規設定' && _originalSettingName == '新規設定') {
        _originalSettingName = null;
      }
    });
  }

  // コントローラーを初期化するヘルパーメソッド
  void _initControllers() {
    _disposeControllers(); // 既存のコントローラーを破棄

    for (final level in _currentLevels) {
      _durationControllers[level.id] = TextEditingController(text: level.durationMinutes.toString());
      _sbControllers[level.id] = TextEditingController(text: level.smallBlind.toString());
      _bbControllers[level.id] = TextEditingController(text: level.bigBlind.toString());
      _anteControllers[level.id] = TextEditingController(text: level.ante.toString());
    }
  }

  // すべてのコントローラーを破棄するヘルパーメソッド
  void _disposeControllers() {
    for (final controller in _durationControllers.values) {
      controller.dispose();
    }
    for (final controller in _sbControllers.values) {
      controller.dispose();
    }
    for (final controller in _bbControllers.values) {
      controller.dispose();
    }
    for (final controller in _anteControllers.values) {
      controller.dispose();
    }
    _durationControllers.clear();
    _sbControllers.clear();
    _bbControllers.clear();
    _anteControllers.clear();
  }

  @override
  void dispose() {
    _tournamentNameController.dispose();
    _disposeControllers(); // すべてのコントローラーを破棄
    super.dispose();
  }

  /// ブラインドレベルを追加する
  void _addBlindLevel({bool isBreak = false}) {
    final newLevel = BlindLevel(
      id: UniqueKey().toString(), // ユニークなIDを生成
      smallBlind: isBreak ? 0 : 100,
      bigBlind: isBreak ? 0 : 200,
      ante: isBreak ? 0 : 0,
      durationMinutes: isBreak ? 10 : 15,
      isBreak: isBreak,
    );
    setState(() {
      _currentLevels.add(newLevel);
      // 新しいレベルに対応するコントローラーを作成
      _durationControllers[newLevel.id] = TextEditingController(text: newLevel.durationMinutes.toString());
      _sbControllers[newLevel.id] = TextEditingController(text: newLevel.smallBlind.toString());
      _bbControllers[newLevel.id] = TextEditingController(text: newLevel.bigBlind.toString());
      _anteControllers[newLevel.id] = TextEditingController(text: newLevel.ante.toString());
    });
  }

  /// ブラインドレベルを削除する
  void _deleteBlindLevel(String id) {
    setState(() {
      _currentLevels.removeWhere((level) {
        if (level.id == id) {
          // 削除されるレベルに対応するコントローラーを破棄
          _durationControllers[id]?.dispose();
          _sbControllers[id]?.dispose();
          _bbControllers[id]?.dispose();
          _anteControllers[id]?.dispose();
          _durationControllers.remove(id);
          _sbControllers.remove(id);
          _bbControllers.remove(id);
          _anteControllers.remove(id);
          return true;
        }
        return false;
      });
    });
  }

  /// 設定を保存する
  Future<void> _saveTournamentSettings() async {
    if (_formKey.currentState!.validate()) {
      // フォームの現在の値をモデルに保存するために、コントローラーの値をモデルに反映させる
      for (final level in _currentLevels) {
        level.durationMinutes = int.tryParse(_durationControllers[level.id]?.text ?? '0') ?? 0;
        level.smallBlind = int.tryParse(_sbControllers[level.id]?.text ?? '0') ?? 0;
        level.bigBlind = int.tryParse(_bbControllers[level.id]?.text ?? '0') ?? 0;
        level.ante = int.tryParse(_anteControllers[level.id]?.text ?? '0') ?? 0;
      }

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

      await settingsService.saveSettings(newSettings); // saveSettings内でlastUsedSettingNameも更新される

      // 保存した設定をタイマーにロード
      timerService.initializeTimer(newSettings);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newSettings.name} が保存されました。')),
      );
    }
  }

  /// 既存の設定をロードするダイアログを表示
  Future<void> _showLoadSettingsDialog() async {
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    // ダイアログ表示前に最新の保存済み設定リストをロード
    await settingsService.initializationComplete; // 初期化完了を待機

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
          await settingsService.loadSettings(selectedSettingName); // loadSettings内でlastUsedSettingNameも更新される
      if (loadedSettings != null) {
        setState(() {
          _tournamentNameController.text = loadedSettings.name;
          _currentLevels = List.from(loadedSettings.levels); // ディープコピー
          _originalSettingName = loadedSettings.name;
          _initControllers(); // ロードした設定でコントローラーを再初期化
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

    // ブラインドレベルの表示文字列を事前に計算し、マップに保存する
    final Map<String, String> calculatedLevelDisplays = {};
    int tempBlindLevelCounter = 0;
    for (final level in _currentLevels) {
      if (level.isBreak) {
        calculatedLevelDisplays[level.id] = 'Break';
      } else {
        tempBlindLevelCounter++;
        calculatedLevelDisplays[level.id] = '$tempBlindLevelCounter';
      }
    }

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
                    SizedBox(
                      width: 80, // アイコンとテキストのスペースを確保
                      child: Row( // アイコンとテキストを横並びにする
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(width: 24), // ドラッグハンドルアイコンとスペースの分を空ける
                          Expanded( // TextをExpandedで囲む
                            child: Text(
                              'Lv',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis, // 必要に応じて省略
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  // buildDefaultDragHandlesをfalseに設定し、カスタムのドラッグハンドルを使用
                  buildDefaultDragHandles: false,
                  itemCount: _currentLevels.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = _currentLevels.removeAt(oldIndex);
                      _currentLevels.insert(newIndex, item);
                      // 並べ替え後もコントローラーの状態は維持されるため、再初期化は不要
                      // ただし、もしコントローラーとモデルの同期が取れていない場合は
                      // ここで_initControllers()を呼び出すことも検討するが、
                      // onChangedでリアルタイム更新しているため不要
                    });
                  },
                  itemBuilder: (context, index) {
                    final level = _currentLevels[index];
                    
                    // 事前に計算された表示文字列をマップから取得
                    final levelDisplay = calculatedLevelDisplays[level.id] ?? '';

                    return Card(
                      key: ValueKey(level.id), // ReorderableListViewにはkeyが必須
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          children: [
                            // ドラッグハンドルアイコンを最も左に配置
                            ReorderableDragStartListener( // ここをドラッグハンドルとする
                              index: index,
                              child: SizedBox(
                                width: 80, // アイコンとテキストのスペースを確保
                                child: Row( // アイコンとテキストを横並びにする
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.drag_handle, size: 20, color: Colors.grey), // ドラッグハンドルアイコン
                                    const SizedBox(width: 4), // アイコンとテキストの間のスペース
                                    Expanded( // TextをExpandedで囲む
                                      child: Text(
                                        levelDisplay, // 調整した表示を使用
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis, // 必要に応じて省略
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 継続時間
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _durationControllers[level.id], // コントローラーを使用
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
                                onChanged: (value) { // 入力時にモデルを更新
                                  level.durationMinutes = int.tryParse(value) ?? 0;
                                },
                              ),
                            ),
                            // Small Blind, Big Blind, Ante
                            if (!level.isBreak) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _sbControllers[level.id], // コントローラーを使用
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
                                  onChanged: (value) { // 入力時にモデルを更新
                                    level.smallBlind = int.tryParse(value) ?? 0;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _bbControllers[level.id], // コントローラーを使用
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
                                  onChanged: (value) { // 入力時にモデルを更新
                                    level.bigBlind = int.tryParse(value) ?? 0;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _anteControllers[level.id], // コントローラーを使用
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
                                  onChanged: (value) { // 入力時にモデルを更新
                                    level.ante = int.tryParse(value) ?? 0;
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

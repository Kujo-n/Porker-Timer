import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:poker_timer_app/screens/settings_screen.dart'; // 設定画面のインポート
import 'package:poker_timer_app/screens/log_screen.dart'; // ログ画面のインポート
import 'package:poker_timer_app/services/timer_service.dart'; // TimerServiceのインポート
import 'package:poker_timer_app/services/log_service.dart'; // LogServiceのインポート
import 'package:poker_timer_app/services/audio_service.dart'; // AudioServiceのインポート

/// アプリのホーム画面
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // コンテンツの推奨最小幅を定義
  static const double kMinContentWidth = 460.0; // 最小幅を460.0に設定

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ポーカータイマー', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer3<TimerService, LogService, AudioService>(
        builder: (context, timerService, logService, audioService, child) {
          final currentLevel = timerService.currentLevel;
          final nextLevel = timerService.nextLevel;

          return LayoutBuilder( // 親ウィジェットの制約を取得
            builder: (context, constraints) {
              // 利用可能な幅が推奨最小幅より小さいか判定
              final bool needsHorizontalScroll = constraints.maxWidth < kMinContentWidth;

              // タイマー表示エリア (開始/一時停止切り替え)
              Widget timerDisplayContent = GestureDetector(
                onTap: () {
                  if (timerService.isRunning) {
                    timerService.pauseTimer(logService);
                  } else {
                    timerService.resumeTimer(logService, audioService);
                  }
                },
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timerService.formatDuration(timerService.remainingSeconds),
                          style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                        const SizedBox(height: 10),
                        Icon(
                          timerService.isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          size: 40,
                          color: timerService.isRunning ? Colors.orange : Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              );

              // 必要に応じて水平スクロール可能なウィジェットでラップ
              if (needsHorizontalScroll) {
                timerDisplayContent = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: kMinContentWidth, // 最小幅を適用
                    child: Center(child: timerDisplayContent), // 中央に配置
                  ),
                );
              } else {
                timerDisplayContent = Center(child: timerDisplayContent);
              }

              return SingleChildScrollView( // 全体を垂直スクロール可能にする (コンテンツが縦に長くなった場合のため)
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 現在のブラインドレベル表示
                      Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              const Text(
                                '現在のブラインドレベル',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                currentLevel?.isBreak == true
                                    ? '休憩中'
                                    : 'SB: ${currentLevel?.smallBlind ?? 0} / BB: ${currentLevel?.bigBlind ?? 0} / Ante: ${currentLevel?.ante ?? 0}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // タイマー表示エリア (条件付きスクロールまたは中央配置)
                      timerDisplayContent,

                      const SizedBox(height: 20),

                      // 戻る/ブラインドリセット/進むボタン
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildIconButton(
                            icon: Icons.arrow_back,
                            onPressed: timerService.currentLevelIndex == 0
                                ? null
                                : () => timerService.previousLevel(logService, audioService),
                            tooltip: '前のレベルに戻る',
                          ),
                          _buildIconButton(
                            icon: Icons.replay, // ブラインドリセットアイコン
                            onPressed: timerService.currentSettings == null || timerService.currentSettings!.levels.isEmpty
                                ? null
                                : () => timerService.resetCurrentLevelTime(logService, audioService), // audioServiceを渡す
                            tooltip: '現在のレベルの時間をリセット',
                          ),
                          _buildIconButton(
                            icon: Icons.arrow_forward,
                            onPressed: timerService.nextLevel == null
                                ? null
                                : () => timerService.skipLevel(logService, audioService),
                            tooltip: '次のレベルに進む',
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 次のブラインドレベル表示
                      Card(
                        margin: const EdgeInsets.only(top: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              const Text(
                                '次のブラインドレベル',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                nextLevel == null
                                    ? '最終レベル'
                                    : nextLevel.isBreak == true
                                        ? '休憩 (${nextLevel.durationMinutes}分)'
                                        : 'SB: ${nextLevel.smallBlind} / BB: ${nextLevel.bigBlind} / Ante: ${nextLevel.ante}',
                                style: const TextStyle(fontSize: 20, color: Colors.deepPurple),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // トーナメント全体のリセットボタン
                      _buildIconButton(
                        icon: Icons.refresh,
                        onPressed: timerService.currentSettings == null
                            ? null
                            : () => timerService.resetTimer(logService),
                        tooltip: 'トーナメントをリセット',
                        isPrimary: true, // リセットボタンを目立たせる
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // アイコンボタンを生成するヘルパーウィジェット
  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip,
    bool isPrimary = false, // 主要なボタンかどうか
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null
            ? Colors.grey[700] // 無効な状態の色
            : isPrimary ? Colors.redAccent : Colors.deepPurple, // 色を調整
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(15), // アイコンのみなのでパディングを調整
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
        shadowColor: Colors.black,
        minimumSize: const Size(60, 60), // ボタンの最小サイズを設定
      ),
      child: Icon(icon, size: 30), // アイコンサイズを調整
    );
  }
}

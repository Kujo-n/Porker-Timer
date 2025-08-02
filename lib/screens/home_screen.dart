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

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool needsHorizontalScroll = constraints.maxWidth < kMinContentWidth;

              // ★ ここでタイマーのフォントサイズをウィンドウ幅から計算
              double timerFontSize = (constraints.maxWidth * 0.15).clamp(40, 360);

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
                    child: Text(
                      timerService.formatDuration(timerService.remainingSeconds),
                      style: TextStyle(
                        fontSize: timerFontSize, // ★ ここを動的に
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ),
              );

              // タイマー＋ボタンをまとめる
              Widget timerDisplayWithButtons = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  timerDisplayContent,
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildIconButton(
                        icon: Icons.arrow_back,
                        onPressed: timerService.currentLevelIndex == 0
                            ? null
                            : () {
                                timerService.previousLevel(logService, audioService);
                                timerService.pauseTimer(logService); // レベル変更後に必ず停止
                              },
                        tooltip: '前のレベルに戻る',
                      ),
                      _buildIconButton(
                        icon: Icons.replay,
                        onPressed: timerService.currentSettings == null || timerService.currentSettings!.levels.isEmpty
                            ? null
                            : () {
                                timerService.resetCurrentLevelTime(logService, audioService);
                                timerService.pauseTimer(logService); // 時間リセット後に必ず停止
                              },
                        tooltip: '現在のレベルの時間をリセット',
                      ),
                      _buildIconButton(
                        icon: Icons.arrow_forward,
                        onPressed: timerService.nextLevel == null
                            ? null
                            : () {
                                timerService.skipLevel(logService, audioService);
                                timerService.pauseTimer(logService); // レベル変更後に必ず停止
                              },
                        tooltip: '次のレベルに進む',
                      ),
                    ],
                  ),
                ],
              );

              if (needsHorizontalScroll) {
                timerDisplayContent = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: kMinContentWidth,
                    child: Center(child: timerDisplayContent),
                  ),
                );
              } else {
                timerDisplayContent = Center(child: timerDisplayContent);
              }

              return SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    children: [
                      // スクロール可能なメインコンテンツ（タイマー表示エリアは含めない）
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 220),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
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

                            const SizedBox(height: 120), // タイマー表示エリア分のスペースを空ける

                            const SizedBox(height: 20),
                            // 他のコンテンツがあればここに追加
                          ],
                        ),
                      ),
                      // タイマー表示エリアをウィンドウ中央に固定
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: false,
                          child: Center(
                            child: timerDisplayWithButtons, // ←ここをtimerDisplayWithButtonsに
                          ),
                        ),
                      ),
                      // 次のブラインドレベル表示エリア（リセットボタンの上に固定）
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 80,
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                      ),
                      // トーナメント全体のリセットボタン（最下部に固定）
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildIconButton(
                            icon: Icons.refresh,
                            onPressed: timerService.currentSettings == null
                                ? null
                                : () => timerService.resetTimer(logService),
                            tooltip: 'トーナメントをリセット',
                            isPrimary: true,
                          ),
                        ),
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

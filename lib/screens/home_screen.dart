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
  static const double kMinContentWidth = 460.0; // 最小幅を410.0に設定

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

              // タイマー表示エリアと操作ボタンのRowウィジェット
              Widget timerAndButtonsContent = Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 戻るボタン
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 48),
                    onPressed: () => timerService.previousLevel(logService, audioService),
                    tooltip: '前のレベルに戻る',
                  ),
                  
                  // タイマー表示 (開始/一時停止切り替え)
                  GestureDetector(
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
                  ),

                  // 進むボタン (スキップ)
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 48),
                    onPressed: () => timerService.skipLevel(logService, audioService),
                    tooltip: '次のレベルに進む',
                  ),
                ],
              );

              // 必要に応じて水平スクロール可能なウィジェットでラップ
              if (needsHorizontalScroll) {
                // SingleChildScrollViewでラップし、SizedBoxで最小幅を確保
                timerAndButtonsContent = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: kMinContentWidth, // 最小幅を適用
                    child: timerAndButtonsContent,
                  ),
                );
              } else {
                // スクロールが不要な場合は中央に配置
                timerAndButtonsContent = Center(child: timerAndButtonsContent);
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

                      // タイマー表示エリアと操作ボタン (条件付きスクロールまたは中央配置)
                      timerAndButtonsContent,


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

                      // リセットボタン
                      ElevatedButton.icon(
                        onPressed: () => timerService.resetTimer(logService),
                        icon: const Icon(Icons.refresh),
                        label: const Text('リセット'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
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
}

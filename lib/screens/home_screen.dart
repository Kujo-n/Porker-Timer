import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:poker_timer_app/services/timer_service.dart'; // TimerServiceのインポート
import 'package:poker_timer_app/services/log_service.dart'; // LogServiceのインポート
import 'package:poker_timer_app/services/audio_service.dart'; // AudioServiceのインポート
import 'package:poker_timer_app/screens/settings_screen.dart'; // SettingsScreenのインポート
import 'package:poker_timer_app/screens/log_screen.dart'; // LogScreenのインポート


/// メインのタイマー表示画面
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final timerService = Provider.of<TimerService>(context);
    final logService = Provider.of<LogService>(context, listen: false);
    final audioService = Provider.of<AudioService>(context, listen: false);

    final currentLevel = timerService.currentLevel;
    final nextLevel = timerService.nextLevel;

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
      body: Container(
        color: Colors.grey[900], // 全体の背景色
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 現在のブラインドレベル表示
                Text(
                  currentLevel?.isBreak == true
                      ? '休憩中'
                      : '現在のブラインドレベル',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent),
                ),
                const SizedBox(height: 10),
                if (currentLevel != null && !currentLevel.isBreak)
                  Text(
                    'SB: ${currentLevel.smallBlind} / BB: ${currentLevel.bigBlind} / Ante: ${currentLevel.ante}',
                    style: const TextStyle(fontSize: 48, color: Colors.white),
                  )
                else if (currentLevel?.isBreak == true)
                  Text(
                    '${currentLevel!.durationMinutes} 分',
                    style: const TextStyle(fontSize: 48, color: Colors.white),
                  ),
                const SizedBox(height: 40),

                // 残り時間表示
                Text(
                  timerService.formatDuration(timerService.remainingSeconds),
                  style: const TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Colors.lightGreenAccent),
                ),
                const SizedBox(height: 40),

                // 次のブラインドレベル表示
                Text(
                  nextLevel != null
                      ? (nextLevel.isBreak ? '次の休憩' : '次のブラインドレベル')
                      : 'トーナメント終了',
                  style: const TextStyle(fontSize: 24, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                if (nextLevel != null && !nextLevel.isBreak)
                  Text(
                    'SB: ${nextLevel.smallBlind} / BB: ${nextLevel.bigBlind} / Ante: ${nextLevel.ante}',
                    style: const TextStyle(fontSize: 36, color: Colors.grey),
                  )
                else if (nextLevel?.isBreak == true)
                  Text(
                    '${nextLevel!.durationMinutes} 分',
                    style: const TextStyle(fontSize: 36, color: Colors.grey),
                  ),
                const SizedBox(height: 60),

                // タイマー操作ボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimerButton(
                      icon: Icons.play_arrow,
                      label: '開始',
                      onPressed: timerService.isRunning || timerService.currentSettings == null
                          ? null
                          : () => timerService.startTimer(logService, audioService),
                    ),
                    const SizedBox(width: 20),
                    _buildTimerButton(
                      icon: Icons.pause,
                      label: '一時停止',
                      onPressed: !timerService.isRunning && !timerService.isPaused
                          ? null
                          : () => timerService.pauseTimer(logService),
                    ),
                    const SizedBox(width: 20),
                    _buildTimerButton(
                      icon: Icons.refresh,
                      label: 'リセット',
                      onPressed: timerService.currentSettings == null
                          ? null
                          : () => timerService.resetTimer(logService),
                    ),
                    const SizedBox(width: 20),
                    _buildTimerButton(
                      icon: Icons.fast_forward,
                      label: 'スキップ',
                      onPressed: timerService.currentSettings == null || timerService.nextLevel == null
                          ? null
                          : () => timerService.skipLevel(logService, audioService),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? Colors.grey[700] : Colors.deepPurple,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
        shadowColor: Colors.black,
      ),
    );
  }
}

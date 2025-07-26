    import 'package:flutter/material.dart';
    import 'package:provider/provider.dart';
    import 'package:poker_timer_app/services/log_service.dart'; // LogServiceのインポート


    /// イベントログ表示画面
    class LogScreen extends StatelessWidget {
      const LogScreen({super.key});

      @override
      Widget build(BuildContext context) {
        final logService = Provider.of<LogService>(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('イベントログ', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.deepPurple,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                onPressed: () async {
                  final confirmClear = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext ctx) => AlertDialog(
                      title: const Text('ログをクリア'),
                      content: const Text('本当に全てのログを削除しますか？'),
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
                  if (confirmClear == true) {
                    await logService.clearLogs();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ログがクリアされました。')),
                    );
                  }
                },
              ),
            ],
          ),
          body: logService.logs.isEmpty
              ? const Center(
                  child: Text(
                    'ログがありません。',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: logService.logs.length,
                  itemBuilder: (context, index) {
                    final entry = logService.logs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.formattedTimestamp,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'タイプ: ${entry.eventType}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '詳細: ${entry.description}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      }
    }
    
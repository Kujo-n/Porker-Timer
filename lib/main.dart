import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:poker_timer_app/services/settings_service.dart';
import 'package:poker_timer_app/services/audio_service.dart';
import 'package:poker_timer_app/services/log_service.dart';
import 'package:poker_timer_app/services/timer_service.dart';
import 'package:poker_timer_app/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => LogService()),
        ChangeNotifierProxyProvider3<SettingsService, AudioService, LogService, TimerService>(
          create: (_) => TimerService(),
          update: (context, settingsService, audioService, logService, timerService) {
            return timerService ?? TimerService();
          },
        ),
      ],
      child: MaterialApp(
        title: 'ポーカータイマー',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Inter',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          cardTheme: CardThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 3,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            labelStyle: const TextStyle(color: Colors.black54),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

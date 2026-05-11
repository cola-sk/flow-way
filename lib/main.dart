import 'package:flutter/material.dart';
import 'pages/map_page.dart';
import 'services/api_service.dart';

void main() {
  runApp(const FlowWayApp());
}

/// 每次打开 App 上报打点（fire-and-forget，不影响启动）
Future<void> _reportAppOpen() async {
  try {
    final apiService = ApiService();
    await apiService.reportEvent('app_open', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    print('上报 app_open 失败: $e');
  }
}

class FlowWayApp extends StatefulWidget {
  const FlowWayApp({super.key});

  @override
  State<FlowWayApp> createState() => _FlowWayAppState();
}

class _FlowWayAppState extends State<FlowWayApp> {
  @override
  void initState() {
    super.initState();
    _reportAppOpen();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6E5E0D),
      brightness: Brightness.light,
      primary: const Color(0xFF6E5E0D),
      secondary: const Color(0xFF855300),
      surface: const Color(0xFFF9F9F8),
    );

    return MaterialApp(
      title: '绕川',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F9F8),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2F3130),
          contentTextStyle: TextStyle(
            color: colorScheme.surface,
            fontWeight: FontWeight.w600,
          ),
          behavior: SnackBarBehavior.floating,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.92),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.88),
          hintStyle: const TextStyle(
            color: Color(0xFF7C7766),
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDCC66E), width: 1),
          ),
        ),
      ),
      home: const MapPage(),
    );
  }
}

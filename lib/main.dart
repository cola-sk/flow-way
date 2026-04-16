import 'package:flutter/material.dart';
import 'pages/map_page.dart';

void main() {
  runApp(const FlowWayApp());
}

class FlowWayApp extends StatelessWidget {
  const FlowWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '绕川',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4CAF50),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}

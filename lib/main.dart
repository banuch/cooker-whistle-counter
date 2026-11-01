import 'package:flutter/material.dart';

import 'counter_page.dart';

void main() => runApp(const WhistleApp());

class WhistleApp extends StatelessWidget {
  const WhistleApp({super.key});

  static ThemeData _theme(Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF6B35),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerHigh.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 6),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whistle Counter',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const CounterPage(),
    );
  }
}

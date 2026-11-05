import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const MangaTranslateApp()); }
class MangaTranslateApp extends StatelessWidget {
  const MangaTranslateApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'MangaTranslate',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF101016),
      colorScheme: const ColorScheme.dark(primary: Color(0xFFB58CFF), secondary: Color(0xFF7C5CDB), surface: Color(0xFF1B1B25)),
      useMaterial3: true),
    home: const HomeScreen());
}

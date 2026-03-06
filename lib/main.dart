// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/location_service.dart';
import 'services/updater_service.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Status bar scura per dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  await LocationService.instance.init();
  await UpdaterService.initNotifications();
  await StorageService.init();
  runApp(const CrmToscanaApp());
}

class CrmToscanaApp extends StatelessWidget {
  const CrmToscanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM Toscana',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      home: StorageService.isLoggedIn() ? const HomeScreen() : const LoginScreen(),
    );
  }

  ThemeData _buildDarkTheme() {
    const bgDark = Color(0xFF0D1117);
    const surfaceDark = Color(0xFF161B22);
    const cardDark = Color(0xFF1C2333);
    const accentGreen = Color(0xFF2E7D32);
    const brightGreen = Color(0xFF4CAF50);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: ColorScheme.dark(
        primary: brightGreen,
        secondary: accentGreen,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        indicatorColor: brightGreen.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: brightGreen, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: Colors.white54, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: brightGreen);
          }
          return const IconThemeData(color: Colors.white54);
        }),
      ),
      chipTheme: ChipThemeData(
        selectedColor: brightGreen.withOpacity(0.3),
        backgroundColor: cardDark,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.white70),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.white30),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentGreen,
        foregroundColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.06)),
    );
  }
}

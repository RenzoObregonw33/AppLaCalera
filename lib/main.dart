// lib/main.dart
import 'package:flutter/material.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lacalera/screens/login_screen.dart';
import 'package:lacalera/screens/home_screen.dart';
import 'package:lacalera/models/user_models.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService.initializeDatabase();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final loginTime = prefs.getInt('login_time');
  final userJson = prefs.getString('user_data');

  Widget initialScreen = const LoginScreen();

  if (token != null && loginTime != null) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final hours48 = 48 * 60 * 60 * 1000; // 48 horas en milisegundos

    if (currentTime - loginTime < hours48) {
      // ✅ Todavía dentro de las 48 horas
      if (userJson != null) {
        try {
          final user = User.fromJson(jsonDecode(userJson));
          initialScreen = HomeScreen(user: user);
        } catch (e) {
          // ❌ Si falla el parseo, volvemos al login
          await prefs.remove('auth_token');
          await prefs.remove('login_time');
          await prefs.remove('user_data');
        }
      }
    } else {
      // ❌ Token vencido → limpiamos datos
      await prefs.remove('auth_token');
      await prefs.remove('login_time');
      await prefs.remove('user_data');
    }
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lacalera App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: initialScreen,
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:besh_league/screens/auth_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    
    // --- הנה הקסם שהופך את כל האפליקציה לעברית ---
    builder: (context, child) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      );
    },
    // ---------------------------------------------
    
    home: const SplashScreen(),
  ));
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // כאן קורה הקסם: מחכים 3 שניות ואז עוברים מסך
    Timer(const Duration(seconds: 3), () {
      // הפקודה Navigator.pushReplacement מחליפה את מסך הטעינה במסך הבא
      // ככה המשתמש לא יכול לחזור אחורה למסך הטעינה עם כפתור ה"חזור"
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/background.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.3)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', width: 250),
                const SizedBox(height: 30),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
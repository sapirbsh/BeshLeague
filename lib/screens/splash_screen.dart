import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:besh_league/screens/auth_screen.dart';
import 'package:besh_league/screens/home_screen.dart';

void main() {
  // שורות קסם שנועלות את האפליקציה לרוחב
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
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
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    // מחכים לפחות 2 שניות כדי להציג את המסך
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final sessionTicket = prefs.getString('sessionTicket');
    final playFabId = prefs.getString('playFabId');

    if (!mounted) return;

    if (sessionTicket != null && sessionTicket.isNotEmpty &&
        playFabId != null && playFabId.isNotEmpty) {
      // יש פרטי התחברות שמורים - עוברים ישירות למסך הבית
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            sessionTicket: sessionTicket,
            playFabId: playFabId,
          ),
        ),
      );
    } else {
      // אין פרטים שמורים - עוברים למסך ההתחברות
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // הרקע שלך
          Image.asset('assets/background.png', fit: BoxFit.cover),

          // שכבה כהה מעט כדי שהלוגו והטעינה יבלטו
          Container(color: Colors.black.withValues(alpha: 0.3)),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // הלוגו
                Image.asset('assets/logo.png', width: 250),
                const SizedBox(height: 30),
                // העיגול המסתובב
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

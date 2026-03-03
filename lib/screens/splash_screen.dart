import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:besh_league/screens/auth_screen.dart';

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
    
    // שינינו את זה ל-5 שניות (5 seconds)
    Timer(const Duration(seconds: 5), () {
      // מוודא שהווידג'ט עדיין קיים לפני הניווט (מונע שגיאות אם המשתמש יצא מהאפליקציה)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AuthScreen()),
        );
      }
    });
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
          Container(color: Colors.black.withOpacity(0.3)),

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
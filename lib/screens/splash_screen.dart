import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final identifier = prefs.getString('loginIdentifier');
    final password   = prefs.getString('loginPassword');
    final isEmail    = prefs.getBool('loginIsEmail') ?? false;

    // ניסיון Silent Login — מתחבר מחדש לשרת כדי לקבל Ticket טרי
    if (identifier != null && identifier.isNotEmpty &&
        password   != null && password.isNotEmpty) {
      try {
        const titleId = "1A15A2";
        final endpoint = isEmail ? 'LoginWithEmailAddress' : 'LoginWithPlayFab';
        final url = Uri.parse('https://$titleId.playfabapi.com/Client/$endpoint');
        final Map<String, dynamic> body = {"TitleId": titleId, "Password": password};
        if (isEmail) {
          body["Email"] = identifier;
        } else {
          body["Username"] = identifier;
        }

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data       = json.decode(response.body)['data'];
          final newTicket  = data['SessionTicket'] as String;
          final newPfId    = data['PlayFabId']     as String;

          await prefs.setString('sessionTicket', newTicket);
          await prefs.setString('playFabId',     newPfId);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                sessionTicket: newTicket,
                playFabId:     newPfId,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint("Silent login failed: $e");
      }
    }

    // אם הכניסה השקטה נכשלה — עוברים למסך ההתחברות
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
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

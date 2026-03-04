import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:besh_league/screens/register_screen.dart';
import 'package:besh_league/screens/home_screen.dart'; 
import 'package:besh_league/screens/about_screen.dart'; 

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("שגיאת התחברות", textAlign: TextAlign.right),
        content: Text(message, textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("הבנתי"),
          )
        ],
      ),
    );
  }

  Future<void> _loginUser() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showErrorDialog("אנא הזן שם משתמש/מייל וסיסמה.");
      return;
    }

    setState(() { _isLoading = true; });

    const titleId = "1A15A2"; 
    final isEmail = identifier.contains('@');
    final endpoint = isEmail ? 'LoginWithEmailAddress' : 'LoginWithPlayFab';
    final url = Uri.parse('https://$titleId.playfabapi.com/Client/$endpoint');

    final Map<String, dynamic> body = {
      "TitleId": titleId,
      "Password": password,
    };

    if (isEmail) {
      body["Email"] = identifier;
    } else {
      body["Username"] = identifier;
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      final responseData = json.decode(response.body);
      setState(() { _isLoading = false; });

      if (response.statusCode == 200) {
        final sessionTicket = responseData['data']['SessionTicket'];
        final playFabId = responseData['data']['PlayFabId'];

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              sessionTicket: sessionTicket, 
              playFabId: playFabId,
            ),
          ),
          (Route<dynamic> route) => false,
        );
      } else {
        String errorMsg = responseData['errorMessage'] ?? "שגיאה לא ידועה.";
        if (errorMsg.contains("User not found")) {
          _showErrorDialog("משתמש לא נמצא. ודא שהקלדת נכון או הירשם.");
        } else if (errorMsg.contains("Invalid password") || errorMsg.contains("password")) {
          _showErrorDialog("הסיסמה שגויה. נסה שוב.");
        } else {
          _showErrorDialog("ההתחברות נכשלה: $errorMsg");
        }
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      _showErrorDialog("שגיאת תקשורת. בדוק את החיבור לאינטרנט.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // הפקודה הזו מונעת מהמסך להתכווץ ולדחוס הכל כשהמקלדת קופצת
      resizeToAvoidBottomInset: false, 
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          // עדכנו את הגדלים שיהיו פרופורציונליים וטובים למסך טלפון
          final logoWidth = screenWidth * 0.15; 
          final buttonWidth = screenWidth * 0.22;
          final textFieldWidth = screenWidth * 0.35;

          return Stack(
            children: [
              // רקע שמתפרס על כל המסך ולא זז
              Positioned.fill(
                child: Image.asset(
                  'assets/background.png', 
                  fit: BoxFit.cover,
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  // מאפשר לגלול קצת כשהמקלדת פתוחה אם צריך
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo.png', width: logoWidth),
                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              _buildTextField("מייל/שם משתמש", controller: _identifierController, width: textFieldWidth),
                              const SizedBox(height: 10),
                              _buildTextField("סיסמה", controller: _passwordController, isPassword: true, width: textFieldWidth),
                            ],
                          ),
                          SizedBox(width: screenWidth * 0.03), 
                          
                          GestureDetector(
                            onTap: _isLoading ? null : _loginUser,
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.black) 
                                : _buildCustomButton("התחברות", width: buttonWidth),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 25),

                      _buildGoogleButton(screenWidth),

                      const SizedBox(height: 15),

                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: _buildCustomButton("הרשמה", width: buttonWidth),
                      ),

                      const SizedBox(height: 10),

                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AboutScreen()),
                          );
                        },
                        child: _buildCustomButton("מי אנחנו", width: buttonWidth * 0.7, isSmall: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- וידג'טים מעוצבים מעודכנים למובייל ---

  Widget _buildTextField(String hint, {required TextEditingController controller, bool isPassword = false, required double width}) {
    return Container(
      width: width,
      // הסרנו את הגובה הקשיח, הקונטיינר יגדל לפי הטקסט וה-Padding
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: TextField(
        controller: controller, 
        obscureText: isPassword,
        textAlign: TextAlign.right, // טקסט מימין לשמאל
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 16), // גודל פונט הגיוני לטלפון
        decoration: InputDecoration(
          hintText: hint,
          // פדינג קבוע ויציב שלא תלוי באחוזי מסך
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: InputBorder.none,
          isDense: true,
          hintStyle: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCustomButton(String text, {required double width, bool isSmall = false}) {
    return Container(
      width: width,
      // משתמשים בפדינג במקום גובה קשיח
      padding: EdgeInsets.symmetric(vertical: isSmall ? 6 : 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB4F0C0), Color(0xFFAEC6F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 4))
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: isSmall ? 16 : 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(double screenWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Google התחבר עם", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
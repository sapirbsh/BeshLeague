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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          final logoWidth = screenWidth * 0.22; 
          final buttonWidth = screenWidth * 0.18;
          final textFieldWidth = screenWidth * 0.28;
          final spacing = screenHeight * 0.04;

          return Stack(
            children: [
              Image.asset(
                'assets/background.png', 
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),

              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo.png', width: logoWidth),
                      SizedBox(height: spacing),

                      // --- כאן נמצא התיקון! הפכנו את הסדר של הפריטים בתוך השורה ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 1. קודם שדות הטקסט (יופיעו בימין בגלל העברית)
                          Column(
                            children: [
                              _buildTextField("מייל/שם משתמש", controller: _identifierController, width: textFieldWidth, height: screenHeight * 0.08),
                              SizedBox(height: spacing * 0.3),
                              _buildTextField("סיסמה", controller: _passwordController, isPassword: true, width: textFieldWidth, height: screenHeight * 0.08),
                            ],
                          ),
                          SizedBox(width: screenWidth * 0.03), // רווח בין השדות לכפתור
                          
                          // 2. אחרי זה כפתור ההתחברות (יופיע בשמאל)
                          GestureDetector(
                            onTap: _isLoading ? null : _loginUser,
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.black) 
                                : _buildCustomButton("התחברות", width: buttonWidth, height: screenHeight * 0.12),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: spacing * 1.5),

                      _buildGoogleButton(screenWidth, screenHeight),

                      SizedBox(height: spacing * 0.8),

                      // כפתור הרשמה
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: _buildCustomButton("הרשמה", width: buttonWidth, height: screenHeight * 0.12),
                      ),

                      SizedBox(height: spacing * 0.5),

                      // כפתור "מי אנחנו" המוקטן
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AboutScreen()),
                          );
                        },
                        child: _buildCustomButton("מי אנחנו", width: buttonWidth * 0.7, height: screenHeight * 0.08),
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

  // --- ווידג'טים מעוצבים ---

  Widget _buildTextField(String hint, {required TextEditingController controller, bool isPassword = false, required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: TextField(
        controller: controller, 
        obscureText: isPassword,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: height * 0.2),
          border: InputBorder.none,
          hintStyle: TextStyle(fontSize: height * 0.35, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCustomButton(String text, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB4F0C0), Color(0xFFAEC6F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(height * 0.4),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 4))
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: height * 0.35, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Google התחבר עם", style: TextStyle(fontSize: screenHeight * 0.035, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
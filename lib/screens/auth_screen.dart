import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
      // 1. בקשת התחברות לשרת
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final sessionTicket = responseData['data']['SessionTicket'];
        final playFabId = responseData['data']['PlayFabId'];

        // 2. --- בדיקת חסימה (Ban) ---
        try {
          final banCheckUrl = Uri.parse('https://$titleId.playfabapi.com/Client/GetUserReadOnlyData');
          final banCheckRes = await http.post(
            banCheckUrl,
            headers: {
              'Content-Type': 'application/json',
              'X-Authorization': sessionTicket, // משתמשים בכרטיס הזמני של השחקן כדי לבדוק אותו
            },
            body: json.encode({"Keys": ["isBanned"]}),
          );

          if (banCheckRes.statusCode == 200) {
            final roData = json.decode(banCheckRes.body)['data']['Data'];
            if (roData != null && roData['isBanned'] != null && roData['isBanned']['Value'] == 'true') {
              // השחקן חסום! זורקים אותו החוצה.
              setState(() { _isLoading = false; });
              _showErrorDialog("החשבון שלך נחסם מהמשחק.\nאנא פנה לתמיכה לקבלת עזרה.");
              return; // עוצרים הכל ולא ממשיכים למסך הבית!
            }
          }
        } catch (e) {
          debugPrint("שגיאה בבדיקת חסימה: $e");
        }
        // -----------------------------

        setState(() { _isLoading = false; });

        // 3. שומרים את פרטי ההתחברות לשימוש עתידי
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sessionTicket', sessionTicket);
        await prefs.setString('playFabId', playFabId);

        // 4. אם הכל תקין והוא לא חסום, מכניסים אותו למסך הבית
        if (mounted) {
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
        }

      } else {
        setState(() { _isLoading = false; });
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
      // מונע את כיווץ המסך כשהמקלדת נפתחת
      resizeToAvoidBottomInset: false, 
      // עוטף את המסך בכיווניות מימין לשמאל (RTL)
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;

            final logoHeight = screenHeight * 0.32;
            final textFieldWidth = screenWidth * 0.35;
            final loginButtonWidth = screenWidth * 0.15;
            final registerButtonWidth = screenWidth * 0.18;
            //final aboutButtonWidth = screenWidth * 0.12;

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/background.png', 
                    fit: BoxFit.cover,
                  ),
                ),

                SafeArea(
                  child: Stack(
                    children: [
                      // כפתור "מי אנחנו" בצד ימין למעלה (בגלל שזה RTL)
                      // כפתור "מי אנחנו" - קטן ובצד ימין למעלה
                    Positioned(
                      top: 10,
                      right: 15,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AboutScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Text("מי אנחנו", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                      // מסך קבוע ללא גלילה! משתמשים ב-Spacer כדי לחלק את הגובה באופן יחסי
                      Column(
                        children: [
                          const Spacer(flex: 2),

                          Image.asset('assets/logo.png', height: logoHeight),
                          
                          const Spacer(flex: 1),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // שדות הטקסט מופיעים ראשונים ולכן יהיו בימין
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTextField("מייל/שם משתמש", controller: _identifierController, width: textFieldWidth),
                                  const SizedBox(height: 10),
                                  _buildTextField("סיסמה", controller: _passwordController, isPassword: true, width: textFieldWidth),
                                ],
                              ),
                              
                              const SizedBox(width: 15), 
                              
                              // כפתור ההתחברות מופיע שני, ולכן יהיה משמאל לשדות
                              GestureDetector(
                                onTap: _isLoading ? null : _loginUser,
                                child: _isLoading 
                                    ? const SizedBox(
                                        width: 35, height: 35, 
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                      ) 
                                    : _buildCustomButton("התחבר", width: loginButtonWidth),
                              ),
                            ],
                          ),
                          
                          const Spacer(flex: 1),

                          _buildGoogleTextButton(),

                          const Spacer(flex: 1),

                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: _buildCustomButton("הרשמה", width: registerButtonWidth),
                          ),
                          
                          const Spacer(flex: 2), 
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, {required TextEditingController controller, bool isPassword = false, required double width}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.5), 
        borderRadius: BorderRadius.circular(4), 
      ),
      child: TextField(
        controller: controller, 
        obscureText: isPassword,
        textAlign: TextAlign.right, 
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: InputBorder.none,
          isDense: true,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCustomButton(String text, {required double width, bool isSmall = false}) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: isSmall ? 6 : 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD0F0C0), Color(0xFFAEC6F5)], 
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        // צורה אובלית/קפסולה לכפתורים
        borderRadius: BorderRadius.circular(30), 
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: isSmall ? 14 : 18, 
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleTextButton() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("התחברות עם Google - בקרוב!", textAlign: TextAlign.center)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Text(
          "התחבר עם Google",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:besh_league/screens/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // בקרים (Controllers) שקוראים את הטופס
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("שגיאה בהרשמה", textAlign: TextAlign.right),
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

Future<void> _registerUser() async {
    // מנקים רווחים מיותרים בהתחלה ובסוף של כל שדה (חשוב מאוד לשרתים)
    final username = _usernameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 1. בדיקה ששום שדה לא ריק (כולל פרטי ומשפחה)
    if (username.isEmpty || firstName.isEmpty || lastName.isEmpty || 
        email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog("אנא מלא את כל השדות בטופס.");
      return;
    }

    // 2. אימות שם משתמש (PlayFab דורש 3-20 תווים, בלי רווחים או תווים מיוחדים)
    if (username.length < 3 || username.length > 20) {
      _showErrorDialog("שם המשתמש חייב להיות בין 3 ל-20 תווים.");
      return;
    }
    // שימוש ב-Regex כדי לוודא ששם המשתמש מכיל רק אותיות באנגלית, מספרים וקו תחתון
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      _showErrorDialog("שם המשתמש יכול להכיל רק אותיות באנגלית, מספרים וקו תחתון (ללא רווחים או עברית).");
      return;
    }

    // 3. אימות אימייל (בדיקת תקינות של שטרודל ונקודה)
    final bool emailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
    if (!emailValid) {
      _showErrorDialog("כתובת האימייל שהוזנה אינה תקינה.");
      return;
    }

    // 4. אימות אורך שם תצוגה (PlayFab מגביל ל-25 תווים)
    final displayName = "$firstName $lastName";
    if (displayName.length < 3 || displayName.length > 25) {
      _showErrorDialog("השם הפרטי ושם המשפחה יחד חייבים להיות בין 3 ל-25 תווים.");
      return;
    }

    // 5. אימות סיסמאות
    if (password != confirmPassword) {
      _showErrorDialog("הסיסמאות אינן תואמות. אנא ודא שהקלדת אותן נכון.");
      return;
    }
    if (password.length < 6 || password.length > 100) {
      _showErrorDialog("הסיסמה חייבת להכיל בין 6 ל-100 תווים.");
      return;
    }

    // --- אם הגענו לפה, הטופס מושלם ועומד בכל חוקי השרת! ---

    setState(() {
      _isLoading = true;
    });

    const titleId = "1A15A2"; 
    final url = Uri.parse('https://$titleId.playfabapi.com/Client/RegisterPlayFabUser');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "TitleId": titleId,
          "Username": username,
          "Email": email,
          "Password": password,
          "DisplayName": displayName,
          "RequireBothUsernameAndEmail": true,
        }),
      );

      final responseData = json.decode(response.body);

      setState(() { _isLoading = false; });
if (response.statusCode == 200) {
        // מציג הודעת הצלחה קצרה
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("הרשמה בוצעה בהצלחה! מעביר למסך הבית...", textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );

        // 1. מחלצים את הנתונים מהשרת של פלייפאב
        final sessionTicket = responseData['data']['SessionTicket'];
        final playFabId = responseData['data']['PlayFabId'];

        // 2. מעבר למסך הבית ומחיקת היסטוריית המסכים - הפעם עם הנתונים!
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
        // במידה ובכל זאת יש שגיאה (למשל אימייל כבר רשום), אנחנו מחלצים אותה
        String errorMsg = responseData['errorMessage'] ?? "שגיאה לא ידועה מול השרת.";
        
        if (errorMsg.contains("Username not available") || errorMsg.contains("NameNotAvailable")) {
          _showErrorDialog("שם המשתמש כבר תפוס, אנא בחר שם אחר.");
        } else if (errorMsg.contains("Email address not available")) {
          _showErrorDialog("כתובת המייל הזו כבר רשומה במערכת.");
        } else {
          // מציג את השגיאה בעברית במידת האפשר
          _showErrorDialog("ההרשמה נכשלה: $errorMsg"); 
        }
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      _showErrorDialog("שגיאת תקשורת. בדוק את החיבור לאינטרנט.");
    }
  }
  // הפונקציה המתוקנת - מדברת ישירות עם השרת של PlayFab!
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black, size: 30),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          return Stack(
            children: [
              Image.asset(
                'assets/background_light.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),

              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Text(
                            "הרשמה",
                            style: TextStyle(
                              fontSize: 50, 
                              fontWeight: FontWeight.bold, 
                              letterSpacing: 1.5,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 3.0 
                                ..color = Colors.black,
                            ),
                          ),
                          const Text(
                            "הרשמה",
                            style: TextStyle(
                              fontSize: 50, 
                              fontWeight: FontWeight.bold, 
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.05),

                      _buildRegisterField("שם משתמש", screenWidth, screenHeight, _usernameController),
                      SizedBox(height: screenHeight * 0.02),
                      _buildRegisterField("שם פרטי", screenWidth, screenHeight, _firstNameController),
                      SizedBox(height: screenHeight * 0.02),
                      _buildRegisterField("שם משפחה", screenWidth, screenHeight, _lastNameController),
                      SizedBox(height: screenHeight * 0.02),
                      _buildRegisterField("כתובת מייל", screenWidth, screenHeight, _emailController),
                      SizedBox(height: screenHeight * 0.02),
                      _buildRegisterField("סיסמה", screenWidth, screenHeight, _passwordController, isPassword: true),
                      SizedBox(height: screenHeight * 0.02),
                      _buildRegisterField("אימות סיסמה", screenWidth, screenHeight, _confirmPasswordController, isPassword: true),
                      
                      SizedBox(height: screenHeight * 0.06),

                      GestureDetector(
                        onTap: _isLoading ? null : _registerUser,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : _buildSubmitButton("צור חשבון", screenWidth, screenHeight),
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

  Widget _buildRegisterField(String hint, double width, double height, TextEditingController controller, {bool isPassword = false}) {
    return Container(
      width: width * 0.4, 
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(String text, double screenWidth, double screenHeight) {
    return Container(
      width: screenWidth * 0.2,
      height: screenHeight * 0.12,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB4F0C0), Color(0xFFAEC6F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 5))
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    );
  }
}
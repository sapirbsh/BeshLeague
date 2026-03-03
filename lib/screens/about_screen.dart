import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // הייבוא לפתיחת המייל

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // הפונקציה שלוחצת על המייל ופותחת את האפליקציה בטלפון
  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@beshleague.com',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      debugPrint('לא ניתן לפתוח את אפליקציית המייל');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // כפתור חזור שקוף למעלה בצד שמאל (מותאם לשפת המכשיר)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black, size: 35),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          return Stack(
            children: [
              // 1. רקע המסך (background_light.png)
              Image.asset(
                'assets/background_light.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),

              // 2. תוכן המסך
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // הלוגו למעלה
                        Image.asset('assets/logo.png', width: screenWidth * 0.18),
                        SizedBox(height: screenHeight * 0.03),

                        // המסגרת היפה עם הטקסט
                        Container(
                          width: screenWidth * 0.7, // רוחב המסגרת
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF87CEEB), width: 4), // מסגרת חיצונית תכלת
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4), // רקע חצי שקוף בתוך המסגרת
                              border: Border.all(color: const Color(0xFF87CEEB), width: 1.5), // מסגרת פנימית עדינה
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "ברוכים הבאים ומקווים שאתם מוכנים להתחיל!\n"
                                  "הבאנו אליכם טורנירים של שש בש עם פרסים אמיתיים.\n"
                                  "חושבים שאתם טובים מספיק?\n"
                                  "הירשמו והבטיחו את מקומכם בליגה הקרובה\n\n"
                                  "מקווים שתהנו,\n"
                                  "לכל שאלה מוזמנים לפנות אלינו",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24, // גודל פונט
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                    height: 1.5, // מרווח בין השורות
                                  ),
                                ),
                                const SizedBox(height: 10),
                                
                                // כפתור המייל הלחיץ
                                GestureDetector(
                                  onTap: _launchEmail,
                                  child: const Text(
                                    "support@beshleague.com",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black, 
                                      // הוספתי קו תחתון עדין כדי שהמשתמש יבין שזה לחיץ, אפשר להוריד אם את מעדיפה בלי
                                      decoration: TextDecoration.underline, 
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
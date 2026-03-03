import 'package:flutter/material.dart';
import 'dart:async';
import 'package:besh_league/screens/game_board_screen.dart'; // ודאי שהקובץ הזה קיים

class PreGameScreen extends StatefulWidget {
  // משתנים שנקבל מהמסך הקודם (כמו שם, גביעים והימור)
  final String myName;
  final int myTrophies;
  final String opponentName;
  final int opponentTrophies;
  final int betAmount; // כמה כל אחד שם (למשל 50)

  const PreGameScreen({
    super.key,
    this.myName = "username",
    this.myTrophies = 12,
    this.opponentName = "יריב",
    this.opponentTrophies = 12,
    this.betAmount = 50,
  });

  @override
  State<PreGameScreen> createState() => _PreGameScreenState();
}

class _PreGameScreenState extends State<PreGameScreen> {
  bool isMeReady = false;
  bool isOpponentReady = false;
  
  int countdown = 3;
  bool isCountingDown = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkBothReady() {
    if (isMeReady && isOpponentReady && !isCountingDown) {
      setState(() {
        isCountingDown = true;
      });
      
      // מתחילים ספירה לאחור של 3 שניות
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (countdown > 1) {
          setState(() {
            countdown--;
          });
        } else {
          timer.cancel();
          // סיום הספירה - מעבר למסך המשחק
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GameBoardScreen()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // סכום הקופה הכולל
    final totalPot = widget.betAmount * 2;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            children: [
              // 1. רקע המסך הכהה
              Image.asset(
                'assets/background_dark.png', // ודאי שיש לך את התמונה בתיקיית assets
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                // אם אין לך עדיין את התמונה הזו, פלאטר ישים רקע חלק, או שתוכלי לשים צבע כהה זמני:
                errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0A192F)),
              ),

              // 2. כפתור לפרוש בצד שמאל למעלה
              Positioned(
                top: height * 0.05,
                left: width * 0.03,
                child: GestureDetector(
                  onTap: () {
                    // חזרה למסך הבית
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB73E3E), // צבע אדום
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Text(
                      "לפרוש",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              // 3. תוכן מרכזי - מחולק ל-3 עמודות
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.05, vertical: height * 0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // --- צד שמאל: היריב ---
                      _buildPlayerColumn(
                        width: width,
                        height: height,
                        name: widget.opponentName,
                        trophies: widget.opponentTrophies,
                        isMe: false,
                        isReady: isOpponentReady,
                      ),

                      // --- אמצע: נתונים משותפים ---
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "VS",
                            style: TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: height * 0.02),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on, color: Colors.amber, size: 50),
                              const SizedBox(width: 10),
                              Text(
                                "$totalPot",
                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          SizedBox(height: height * 0.05),
                          // אייקון צ'אט (זמני)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.chat_bubble, color: Colors.greenAccent, size: 50),
                              Positioned(
                                right: -15,
                                bottom: -10,
                                child: Icon(Icons.chat_bubble, color: Colors.grey[300], size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // --- צד ימין: המשתמש שלי ---
                      _buildPlayerColumn(
                        width: width,
                        height: height,
                        name: widget.myName,
                        trophies: widget.myTrophies,
                        isMe: true,
                        isReady: isMeReady,
                      ),
                    ],
                  ),
                ),
              ),

              // 4. מסך ספירה לאחור (מופיע רק כששניהם מוכנים)
              if (isCountingDown)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Text(
                      "$countdown",
                      style: const TextStyle(
                        fontSize: 150,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.blueAccent, blurRadius: 20)],
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

  // --- וידג'ט שבונה את העמודה של השחקן (תמונה, פרטים וכפתור מוכן) ---
  Widget _buildPlayerColumn({
    required double width,
    required double height,
    required String name,
    required int trophies,
    required bool isMe,
    required bool isReady,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // תמונת פרופיל עם לבבות
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: height * 0.35,
              height: height * 0.35,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Icon(Icons.person, size: height * 0.25, color: Colors.grey[600]),
            ),
            Positioned(
              bottom: -10,
              right: -15,
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.blueAccent, size: 25),
                  const Icon(Icons.favorite, color: Colors.purple, size: 40),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: height * 0.05),

        // שם המשתמש
        Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: height * 0.01),

        // גביעים
        Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
            const SizedBox(width: 10),
            Text("$trophies", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        SizedBox(height: height * 0.01),

        // מטבעות
        Row(
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
            const SizedBox(width: 10),
            Text("${widget.betAmount}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        
        SizedBox(height: height * 0.05),

        // אזור הכפתור / כיתוב READY
        SizedBox(
          height: height * 0.12,
          child: isReady 
              ? _buildReadySticker() // אם מוכן, מציג את הסטריקר
              : _buildStatusButton(isMe, width, height), // אם לא, מציג את הכפתור
        ),
      ],
    );
  }

  // --- מדבקת ה-READY היפה ---
  Widget _buildReadySticker() {
    return Stack(
      children: [
        // צללית שחורה עבה
        Text(
          "READY",
          style: TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10
              ..color = Colors.black,
          ),
        ),
        // הטקסט עצמו בצבע תכלת מטאלי
        const Text(
          "READY",
          style: TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            color: Color(0xFFA8E6CF),
          ),
        ),
      ],
    );
  }

  // --- כפתורי "מוכן" ו"בהמתנה" ---
  Widget _buildStatusButton(bool isMe, double width, double height) {
    if (isMe) {
      // הכפתור הירוק שלי
      return GestureDetector(
        onTap: () {
          setState(() { isMeReady = true; });
          _checkBothReady();
        },
        child: Container(
          width: width * 0.15,
          decoration: BoxDecoration(
            color: const Color(0xFF9DE05C), // ירוק בהיר כמו בתמונה
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text("מוכן", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      );
    } else {
      // כפתור ההמתנה של היריב (עשיתי אותו לחיץ רק בשביל הבדיקות שלך!)
      return GestureDetector(
        onTap: () {
          setState(() { isOpponentReady = true; });
          _checkBothReady();
        },
        child: Container(
          width: width * 0.15,
          decoration: BoxDecoration(
            color: const Color(0xFF5A667D), // אפור כחלחל
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text("בהמתנה", style: TextStyle(fontSize: 22, color: Colors.white70)),
          ),
        ),
      );
    }
  }
}
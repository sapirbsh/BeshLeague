import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:besh_league/screens/game_board_screen.dart'; 

class PreGameScreen extends StatefulWidget {
  // המשתנים של השרת החי והמשחק
  final String sessionTicket;
  final String roomId;
  final String myPlayFabId;
  final String myName;
  final int myTrophies;
  final String opponentId;
  final String opponentName;
  final int opponentTrophies;
  final int betAmount;

  const PreGameScreen({
    super.key,
    this.sessionTicket = "",
    this.roomId = "",
    this.myPlayFabId = "me_123",
    this.myName = "username",
    this.myTrophies = 12,
    this.opponentId = "opp_456",
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
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // מתחילים להאזין לשרת ברגע שהמסך עולה (אם יש חיבור אמיתי)
    if (widget.roomId.isNotEmpty && widget.sessionTicket.isNotEmpty) {
      _initRoomAndListen();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // --- פונקציות שרת: חיבור ודגימה ---
  Future<void> _initRoomAndListen() async {
    const titleId = "1A15A2"; 
    // מייצר את החדר המשותף (רק מי שפונה ראשון באמת ייצור אותו)
    try {
      await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "FunctionName": "CreateMatchRoom",
          "FunctionParameter": { "OpponentId": widget.opponentId }
        }),
      );
    } catch (e) {}

    // מתחיל לבדוק כל שנייה אם היריב לחץ על כפתור "מוכן"
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkIfBothReadyOnServer();
    });
  }

  Future<void> _checkIfBothReadyOnServer() async {
    const titleId = "1A15A2"; 
    try {
      final res = await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/GetSharedGroupData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({ 
          "SharedGroupId": widget.roomId, 
          "Keys": ["${widget.myPlayFabId}_ready", "${widget.opponentId}_ready"] 
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data']?['Data'];
        if (data != null) {
          bool opponentR = data["${widget.opponentId}_ready"]?["Value"] == "true";
          bool meR = data["${widget.myPlayFabId}_ready"]?["Value"] == "true";
          
          if (mounted && opponentR != isOpponentReady) {
            setState(() { isOpponentReady = opponentR; });
          }

          // אם שנינו מוכנים והספירה לא החלה - מתחילים!
          if (meR && opponentR && !isCountingDown) {
            _startCountdownAndGo();
          }
        }
      }
    } catch (e) {}
  }

  // כשאני לוחצת על הכפתור "מוכן" שלי
  Future<void> _setReady() async {
    setState(() { isMeReady = true; });
    
    if (widget.sessionTicket.isNotEmpty && widget.roomId.isNotEmpty) {
      const titleId = "1A15A2"; 
      // מעדכן את השרת שאני מוכנה
      await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/UpdateSharedGroupData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "SharedGroupId": widget.roomId,
          "Data": { "${widget.myPlayFabId}_ready": "true" }
        }),
      );
    } else {
      // במידה וזה רק סימולציה/בדיקת עיצוב בלי שרת
      if (isOpponentReady && !isCountingDown) {
        _startCountdownAndGo();
      }
    }
  }

  // --- ספירה לאחור ומעבר למשחק ---
  void _startCountdownAndGo() {
    _pollingTimer?.cancel();
    setState(() {
      isCountingDown = true;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        setState(() {
          countdown--;
        });
      } else {
        timer.cancel();
        // מעבירים את כל המידע מהשרת למסך הלוח החי!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => GameBoardScreen(
            sessionTicket: widget.sessionTicket,
            roomId: widget.roomId,
            myPlayFabId: widget.myPlayFabId,
            myName: widget.myName,
            myTrophies: widget.myTrophies,
            opponentId: widget.opponentId,
            opponentName: widget.opponentName,
            opponentTrophies: widget.opponentTrophies,
            betAmount: widget.betAmount,
          )),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPot = widget.betAmount * 2;

    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl, // מוודא שאני בימין והיריב בשמאל!
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return Stack(
              children: [
                // 1. רקע המסך הכהה
                Image.asset(
                  'assets/background_dark.png', 
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0A192F)),
                ),

                // 2. כפתור לפרוש בצד ימין למעלה (RTL משפיע על Positioned!)
                Positioned(
                  top: height * 0.05,
                  right: width * 0.03, // right כי אנחנו ב-RTL
                  child: GestureDetector(
                    onTap: () {
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
                        // --- צד ימין (בגלל שזה RTL): המשתמש שלי ---
                        _buildPlayerColumn(
                          width: width,
                          height: height,
                          name: widget.myName,
                          trophies: widget.myTrophies,
                          isMe: true,
                          isReady: isMeReady,
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
                            // אייקון צ'אט
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

                        // --- צד שמאל: היריב ---
                        _buildPlayerColumn(
                          width: width,
                          height: height,
                          name: widget.opponentName,
                          trophies: widget.opponentTrophies,
                          isMe: false,
                          isReady: isOpponentReady,
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. מסך ספירה לאחור הענק (מופיע רק כששניהם מוכנים)
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

        Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: height * 0.01),

        Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
            const SizedBox(width: 10),
            Text("$trophies", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        SizedBox(height: height * 0.01),

        Row(
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
            const SizedBox(width: 10),
            Text("${widget.betAmount}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        
        SizedBox(height: height * 0.05),

        SizedBox(
          height: height * 0.12,
          child: isReady 
              ? _buildReadySticker() 
              : _buildStatusButton(isMe, width, height),
        ),
      ],
    );
  }

  // --- מדבקת ה-READY היפה ---
  Widget _buildReadySticker() {
    return Stack(
      children: [
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
      return GestureDetector(
        onTap: _setReady, // קורא לפונקציית השרת שבנינו למעלה!
        child: Container(
          width: width * 0.15,
          decoration: BoxDecoration(
            color: const Color(0xFF9DE05C),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text("מוכן", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      );
    } else {
      return GestureDetector(
        // לחיץ רק אם אנחנו עושים בדיקות בלי שרת. בחיים האמיתיים זה ננעל ומחכה שהיריב ילחץ אצלו!
        onTap: widget.sessionTicket.isEmpty ? () {
          setState(() { isOpponentReady = true; });
          if (isMeReady && !isCountingDown) _startCountdownAndGo();
        } : null,
        child: Container(
          width: width * 0.15,
          decoration: BoxDecoration(
            color: const Color(0xFF5A667D),
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
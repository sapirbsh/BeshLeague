import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter_markdown/flutter_markdown.dart'; 
import 'package:besh_league/screens/auth_screen.dart';
import 'package:besh_league/screens/about_screen.dart'; 
import 'package:besh_league/screens/pre_game_screen.dart';
import 'package:url_launcher/url_launcher.dart';


class HomeScreen extends StatefulWidget {
  final String sessionTicket;
  final String playFabId;

  const HomeScreen({super.key, required this.sessionTicket, required this.playFabId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String playfabUsername = "טוען..."; 
  String userEmail = ""; 
  bool _isFriendsPanelOpen = false;
  bool _isNavigatingToGame = false;
  int coins = 0;
  int trophies = 0;
  int xp = 0;
  int dailyGamesPlayed = 0;
  int streakDays = 0;
  String _lastStreakDate = '';
  String lastLogin = "טוען...";
  int leaguesPlayed = 0; 
  int totalWins = 0;
  int totalLosses = 0;
  bool isLoadingData = true;

  List<dynamic> friendsList = []; 
  List<dynamic> friendRequests = []; 
  
  List<String> onlineFriendIds = [];

  final TextEditingController _friendAddController = TextEditingController();
  bool _isAddingFriend = false; 

  Timer? _liveRefreshTimer;

  bool isIncomingDuelOpen = false;
  BuildContext? waitingDialogContext;

  final String termsOfServiceMarkdown = '''
תקנון ותנאי שימוש באפליקציית BeshLeague

​ברוכים הבאים ל-BeshLeague אנו שמחים לארח אתכם בקהילת השחקנים שלנו. שימוש באפליקציה מותנה בהסכמתכם לתנאים המפורטים בתקנון זה. אנא קראו אותם בקפידה.

מבוא והגבלת גיל
​1.1. האפליקציה מיועדת לשימוש עבור תושבי מדינת ישראל בלבד.
1.2. השימוש באפליקציה, לרבות השתתפות בליגות וביצוע רכישות, מותר אך ורק למשתמשים בני 18 ומעלה. בהרשמתך לאפליקציה, אתה מצהיר כי גילך מעל 18.
1.3. ההרשמה מתבצעת באמצעות חשבון גוגל (Google), אפל (Apple) או יצירת משתמש ייעודי (אימייל וסיסמה). המשתמש אחראי לשמור על סודיות פרטי ההתחברות שלו.

​הוראות וחוקי המשחק
​2.1. האפליקציה מציעה משחק שש-בש קלאסי. מטרת המשחק היא להעביר את כל הכלים שלך אל הבית ולהוציא אותם החוצה לפני היריב, בהתאם לתוצאות הטלת הקוביות.
2.2. מצבי משחק:
​משחק אקראי: התאמה אוטומטית מול שחקן אחר ברשת.
​משחק מול חבר: הזמנת חבר למשחק פרטי דרך רשימת החברים.
2.3. הימורים וירטואליים במשחק: לפני תחילת משחק מול חבר או שחקן אקראי, שני השחקנים יסכימו על סכום "הימור" של מטבעות וירטואליים. המשחק יתחיל רק לאחר אישור הסכום על ידי שני הצדדים. המנצח יזכה בקופה הווירטואלית.

​	כלכלה וירטואלית ורכישות באפליקציה (In-App Purchases)
​סעיף זה קריטי לאישור בחנויות האפליקציות
3.1. האפליקציה מאפשרת רכישה של "מטבעות משחק" באמצעות כסף אמיתי דרך מנגנוני התשלום של Apple App Store ו-Google Play.
3.2. המטבעות הם וירטואליים בלבד. אין להם כל ערך כספי בעולם האמיתי. לא ניתן בשום מקרה להמיר, לפדות או למשוך את המטבעות הווירטואליים חזרה לכסף אמיתי.
3.3. המטבעות נועדו אך ורק לשימוש בתוך האפליקציה: "הימור" במשחקים מול שחקנים אחרים, ורכישת פריטים קוסמטיים (סקינים, מסגרות, קוביות מיוחדות).
3.4. כל הרכישות באפליקציה הן סופיות. לא יינתן החזר כספי (Refund) בגין רכישת מטבעות או פריטים וירטואליים, למעט כפי שמתחייב בחוק הגנת הצרכן או במדיניות ההחזרים של אפל/גוגל.

​	ליגות תחרותיות ופרסים (Leaderboards & Rewards)
​4.1. האפליקציה מפעילה ליגות תחרותיות המתחדשות מדי חודש. עלייה בליגות מבוססת על צבירת נקודות ניסיון/ניצחונות.
4.2. בסיום כל חודש קלנדרי, השחקנים המובילים בדירוג יזכו בפרסים ממשיים (כגון שובר מתנה - Gift Card, או העברה באפליקציות תשלום כגון Bit).
4.3. הנהלת האפליקציה תיצור קשר עם הזוכים לצורך העברת הפרס. חלוקת הפרסים נתונה לשיקול דעתה הבלעדי של הנהלת האפליקציה, והיא רשאית לשנות את סוג וכמות הפרסים מחודש לחודש.
4.4. הבהרה משפטית חובה: חברת Apple Inc. וחברת Google LLC אינן נותנות חסות, אינן מעורבות, ואינן קשורות בשום צורה ואופן לליגות, לתחרויות או לחלוקת הפרסים באפליקציה זו.

התנהגות משתמשים, צ'אט ותוכן גולשים (EULA - Zero Tolerance)
​סעיף חובה לאישור צ'אט באפליקציה
5.1. האפליקציה מאפשרת תקשורת בין שחקנים באמצעות צ'אט חי בלובי המשחק.
5.2. אפס סובלנות לתוכן פוגעני: חל איסור מוחלט על שימוש בשפה פוגענית, קללות, איומים, הטרדות, גזענות, או כל תוכן מיני/אלים.
5.3. דיווח וחסימה: האפליקציה כוללת כפתור "דווח" (Report) וכפתור "חסום שחקן" (Block). משתמשים נדרשים לדווח על כל התנהגות בלתי הולמת.
5.4. הנהלת האפליקציה רשאית לחסום, להשעות או למחוק לצמיתות חשבון של משתמש שיפר כללים אלו, כולל החרמת כל המטבעות הווירטואליים שברשותו, ללא הודעה מוקדמת וללא פיצוי.

​פרטיות ומידע (תקציר מדיניות פרטיות)
​6.1. אנו מכבדים את פרטיותך. האפליקציה אוספת אך ורק את המידע הדרוש ליצירת חשבון (שם משתמש, כתובת אימייל או מזהה התחברות מגוגל/אפל) ושמירת התקדמות המשחק.
6.2. האפליקציה אינה אוספת או דורשת הרשאת גישה למיקום (GPS), לאנשי הקשר, למצלמה או לגלריית התמונות שלך.
6.3. נתוני התשלום מאובטחים ומנוהלים בלעדית על ידי החנויות (Apple/Google). האפליקציה אינה שומרת פרטי אשראי.

​זכויות יוצרים וקניין רוחני
​7.1. כל הזכויות, לרבות קוד האפליקציה, העיצוב, הלוגו, הסקינים, הקוביות והגרפיקה שייכים בלעדית ליוצרי האפליקציה. אין להעתיק, לשכפל או להפיץ כל חלק מהאפליקציה ללא אישור בכתב.

​	שינויים ותמיכה
​8.1. אנו רשאים לעדכן תקנון זה מעת לעת. המשך השימוש באפליקציה לאחר העדכון מהווה הסכמה לתנאים החדשים.
8.2. לשאלות, דיווח על תקלות או פניות בנושא התקנון, ניתן לפנות אלינו לכתובת הדוא"ל: support@beshleague.com
''';

  @override
  void initState() {
    super.initState();
    _fetchPlayerData(); 
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchPlayerData(isBackground: true); 
    });
  }

  @override
  void dispose() {
    _friendAddController.dispose();
    _liveRefreshTimer?.cancel(); 
    super.dispose();
  }

  String _formatDate(String isoString) {
    try {
      DateTime date = DateTime.parse(isoString).toLocal();
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "לא ידוע";
    }
  }

  Future<void> _updateLoginTimesInServer(String currentLogin, String previousLogin) async {
    const titleId = "1A15A2";
    await http.post(
      Uri.parse('https://$titleId.playfabapi.com/Client/UpdateUserData'),
      headers: {
        'Content-Type': 'application/json',
        'X-Authorization': widget.sessionTicket,
      },
      body: json.encode({
        "Data": {
          "CurrentLogin": currentLogin,
          "PreviousLogin": previousLogin
        },
        "Permission": "Public"
      }),
    );
  }

  Future<void> _fetchPlayerData({bool isBackground = false}) async {
    const titleId = "1A15A2"; 
    final headers = {
      'Content-Type': 'application/json',
      'X-Authorization': widget.sessionTicket, 
    };

    try {
      final accountRes = await http.post(Uri.parse('https://$titleId.playfabapi.com/Client/GetAccountInfo'), headers: headers, body: '{}');
      final accountData = json.decode(accountRes.body);

      final inventoryRes = await http.post(Uri.parse('https://$titleId.playfabapi.com/Client/GetUserInventory'), headers: headers, body: '{}');
      final inventoryData = json.decode(inventoryRes.body);

      final friendsRes = await http.post(Uri.parse('https://$titleId.playfabapi.com/Client/GetFriendsList'), headers: headers, body: '{}');
      List<dynamic> fetchedFriends = [];
      if (friendsRes.statusCode == 200) {
        fetchedFriends = json.decode(friendsRes.body)['data']?['Friends'] ?? [];
      }

      final heartbeatRes = await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
        headers: headers,
        body: json.encode({"FunctionName": "UpdateHeartbeat"}),
      );
      
      List<String> fetchedOnlineIds = [];
      if (heartbeatRes.statusCode == 200) {
        final hbData = json.decode(heartbeatRes.body);
        if (hbData['data'] != null && hbData['data']['FunctionResult'] != null) {
          final result = hbData['data']['FunctionResult'];
          if (result['onlineFriends'] != null) {
            for(var id in result['onlineFriends']) {
                fetchedOnlineIds.add(id.toString());
            }
          }
        }
      }

      final userDataRes = await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/GetUserData'), 
        headers: headers, 
        body: json.encode({"Keys": ["FriendRequests", "DuelRequests", "DuelStatus", "CurrentLogin", "PreviousLogin", "TotalXP", "DailyGamesPlayed", "StreakDays", "LastStreakDate", "Wins", "Losses"]})
      );
      
      List<dynamic> fetchedRequests = [];
      List<dynamic> fetchedDuelRequests = [];
      Map<String, dynamic>? duelStatus;
      String savedCurrentLogin = "";
      String savedPreviousLogin = "";
      int fetchedXp = 0;
      int fetchedStreakDays = 0;
      String fetchedLastStreakDate = '';
      int fetchedWins = 0;
      int fetchedLosses = 0;

      if (userDataRes.statusCode == 200) {
        final userData = json.decode(userDataRes.body)['data']?['Data'];
        if (userData != null) {
          if (userData['FriendRequests'] != null) fetchedRequests = json.decode(userData['FriendRequests']['Value']);
          if (userData['DuelRequests'] != null) fetchedDuelRequests = json.decode(userData['DuelRequests']['Value']);
          if (userData['DuelStatus'] != null) duelStatus = json.decode(userData['DuelStatus']['Value']);
          
          if (userData['CurrentLogin'] != null) savedCurrentLogin = userData['CurrentLogin']['Value'];
          if (userData['PreviousLogin'] != null) savedPreviousLogin = userData['PreviousLogin']['Value'];
          fetchedXp = int.tryParse(userData['TotalXP']?['Value'] ?? '0') ?? 0;
          fetchedStreakDays = int.tryParse(userData['StreakDays']?['Value'] ?? '0') ?? 0;
          fetchedLastStreakDate = userData['LastStreakDate']?['Value'] ?? '';
          fetchedWins = int.tryParse(userData['Wins']?['Value'] ?? '0') ?? 0;
          fetchedLosses = int.tryParse(userData['Losses']?['Value'] ?? '0') ?? 0;
          final fetchedDailyGames = int.tryParse(userData['DailyGamesPlayed']?['Value'] ?? '0') ?? 0;
          final lastGameDateStr = userData['LastGameDate']?['Value'] ?? '';
          final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
          if (mounted) {
            setState(() { dailyGamesPlayed = lastGameDateStr == today ? fetchedDailyGames : 0; });
          }
        }
      }

      if (mounted) {
        if (fetchedDuelRequests.isNotEmpty && !isIncomingDuelOpen) {
          isIncomingDuelOpen = true;
          final firstRequest = fetchedDuelRequests[0];
          final incomingBet = int.tryParse(firstRequest['betAmount'].toString()) ?? 50;
          final senderId = firstRequest['senderId']; 
          _showIncomingDuelDialog(firstRequest['senderName'].toString(), senderId, incomingBet);
        }

        if (duelStatus != null) {
          if (duelStatus['status'] == 'declined') {
            if (waitingDialogContext != null) {
               Navigator.of(waitingDialogContext!).pop();
               waitingDialogContext = null;
            }
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("היריב סירב להזמנה.", textAlign: TextAlign.right), backgroundColor: Colors.redAccent));
            _clearDuelStatus(); 
          } 
          else if (duelStatus['status'] == 'accepted') {
            if (waitingDialogContext != null) {
               Navigator.of(waitingDialogContext!).pop();
               waitingDialogContext = null;
            }
            _clearDuelStatus();
            
            final acceptedBet = int.tryParse(duelStatus['betAmount'].toString()) ?? 50;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PreGameScreen(
                  sessionTicket: widget.sessionTicket,
                  myPlayFabId: widget.playFabId,
                  myName: playfabUsername,
                  myTrophies: trophies,
                  opponentName: duelStatus!['opponent'].toString(),
                  opponentId: duelStatus['opponentId']?.toString() ?? "",
                  opponentTrophies: 0,
                  betAmount: acceptedBet,
                  roomId: duelStatus['roomId']?.toString() ?? "",
                ),
              ),
            ).then((_) { if (mounted) _fetchPlayerData(); });
          }
        }

        if (accountRes.statusCode == 200 && inventoryRes.statusCode == 200) {
          final userInfo = accountData['data']['AccountInfo'];
          final titleInfo = userInfo['TitleInfo'];
          final privateInfo = userInfo['PrivateInfo']; 
          
          final virtualCurrency = inventoryData['data']['VirtualCurrency'];
          final fetchedCoins = (virtualCurrency != null && virtualCurrency['CO'] != null) ? virtualCurrency['CO'] : 500; 

          String currentPfLogin = titleInfo['LastLogin'] ?? "";
          String displayLoginStr = "טוען...";

          if (currentPfLogin.isNotEmpty && currentPfLogin != savedCurrentLogin) {
            if (savedCurrentLogin.isNotEmpty) {
                displayLoginStr = _formatDate(savedCurrentLogin);
            } else {
                displayLoginStr = "התחברות ראשונה";
            }
            _updateLoginTimesInServer(currentPfLogin, savedCurrentLogin);
          } else {
            if (savedPreviousLogin.isNotEmpty) {
                displayLoginStr = _formatDate(savedPreviousLogin);
            } else {
                displayLoginStr = "התחברות ראשונה";
            }
          }

          setState(() {
            playfabUsername = userInfo['Username'] ?? "שחקן";
            userEmail = privateInfo?['Email'] ?? "";
            coins = fetchedCoins;
            xp = fetchedXp;
            streakDays = fetchedStreakDays;
            _lastStreakDate = fetchedLastStreakDate;
            totalWins = fetchedWins;
            totalLosses = fetchedLosses;
            lastLogin = displayLoginStr;
            friendsList = fetchedFriends;
            friendRequests = fetchedRequests;
            onlineFriendIds = fetchedOnlineIds;
            isLoadingData = false;
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _clearDuelStatus() async {
    const titleId = "1A15A2"; 
    await http.post(
      Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
      headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
      body: json.encode({"FunctionName": "ClearDuelStatus"}),
    );
  }

  void _showDuelInviteDialog(String friendUsername) {
    int selectedBet = 50; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final size = MediaQuery.of(context).size;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: size.width * 0.55, 
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2328).withOpacity(0.95), 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 30, color: Colors.white),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        const FittedBox(fit: BoxFit.scaleDown, child: Text("הזמנה לדו-קרב", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("אני", style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 15), child: Text("VS", style: TextStyle(fontSize: 30, color: Colors.amber, fontWeight: FontWeight.bold))),
                        Text(friendUsername, style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBetOption(50, selectedBet, () => setStateDialog(() => selectedBet = 50)),
                        _buildBetOption(100, selectedBet, () => setStateDialog(() => selectedBet = 100)),
                        _buildBetOption(200, selectedBet, () => setStateDialog(() => selectedBet = 200)),
                      ],
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28559A),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        if (coins < selectedBet) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("אין לך מספיק מטבעות!", textAlign: TextAlign.right), backgroundColor: Colors.redAccent));
                          return;
                        }
                        
                        Navigator.of(ctx).pop(); 
                        _sendDuelInviteToServer(friendUsername, selectedBet);
                      },
                      child: const Text("הזמן", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildBetOption(int amount, int currentSelection, VoidCallback onSelect) {
    bool isSelected = amount == currentSelection;
    bool canAfford = coins >= amount;

    return GestureDetector(
      onTap: () {
        if (canAfford) {
          onSelect();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("אין לך מספיק מטבעות.", textAlign: TextAlign.right), backgroundColor: Colors.redAccent));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC4E4F5) : Colors.black, 
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: canAfford ? Colors.amber : Colors.grey, width: 2),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.blueAccent, blurRadius: 8)] : [],
        ),
        child: Row(
          children: [
            Icon(Icons.monetization_on, color: canAfford ? Colors.amber : Colors.grey, size: 22),
            const SizedBox(width: 5),
            Text("$amount", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : (canAfford ? Colors.white : Colors.grey))),
          ],
        ),
      ),
    );
  }

  Future<void> _sendDuelInviteToServer(String targetUsername, int betAmount) async {
    _showWaitingForOpponentDialog(targetUsername);
    const titleId = "1A15A2"; 

    try {
      final accountUrl = Uri.parse('https://$titleId.playfabapi.com/Client/GetAccountInfo');
      final accountRes = await http.post(
        accountUrl,
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"Username": targetUsername}), 
      );
      final accountData = json.decode(accountRes.body);

      if (accountRes.statusCode != 200) {
        if (waitingDialogContext != null) {
          Navigator.of(waitingDialogContext!).pop();
          waitingDialogContext = null;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("שגיאה במציאת היריב.", textAlign: TextAlign.right), backgroundColor: Colors.redAccent));
        return;
      }

      final targetPlayFabId = accountData['data']['AccountInfo']['PlayFabId'];

      await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "FunctionName": "SendDuelInvite",
          "FunctionParameter": { "TargetPlayFabId": targetPlayFabId, "BetAmount": betAmount }
        }),
      );
    } catch (e) {
      if (waitingDialogContext != null) {
        Navigator.of(waitingDialogContext!).pop();
        waitingDialogContext = null;
      }
    }
  }

  void _showWaitingForOpponentDialog(String friendUsername) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        waitingDialogContext = ctx; 
        final size = MediaQuery.of(context).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: size.width * 0.45,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2328).withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 28, color: Colors.white),
                    onPressed: () {
                      waitingDialogContext = null;
                      _clearDuelStatus(); 
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ביטלת את ההזמנה.", textAlign: TextAlign.right)));
                    },
                  ),
                ),
                const CircularProgressIndicator(color: Colors.amber),
                const SizedBox(height: 20),
                Text("ממתין לאישור מ-$friendUsername...", textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.white)),
              ],
            ),
          ),
        );
      }
    ).then((_) => waitingDialogContext = null);
  }

  void _showIncomingDuelDialog(String senderUsername, String senderId, int incomingBet) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: size.width * 0.5,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2328).withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 30, color: Colors.white),
                        onPressed: () {
                          isIncomingDuelOpen = false;
                          Navigator.of(ctx).pop();
                          _respondToDuelInvite(senderUsername, senderId, false); 
                        },
                      ),
                    ),
                    const FittedBox(fit: BoxFit.scaleDown, child: Text("הזמנה לדו-קרב", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white))),
                  ],
                ),
                const SizedBox(height: 20),
                
                Text('"$senderUsername" הזמין אותך לדו קרב', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: Colors.white)),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFC4E4F5), borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
                      const SizedBox(width: 8),
                      Text("$incomingBet", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28559A),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    isIncomingDuelOpen = false;
                    Navigator.of(ctx).pop();
                    if (coins < incomingBet) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("אין לך מספיק מטבעות לאישור הדו-קרב.", textAlign: TextAlign.right), backgroundColor: Colors.redAccent));
                      _respondToDuelInvite(senderUsername, senderId, false); 
                    } else {
                      _respondToDuelInvite(senderUsername, senderId, true); 
                    }
                  },
                  child: const Text("אישור", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _respondToDuelInvite(String senderUsername, String senderId, bool isAccept) async {
    const titleId = "1A15A2";
    final res = await http.post(
      Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
      headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
      body: json.encode({
        "FunctionName": "RespondDuelInvite",
        "FunctionParameter": { "SenderUsername": senderUsername, "SenderId": senderId, "IsAccept": isAccept }
      }),
    );

    if (isAccept && res.statusCode == 200 && mounted) {
      final data = json.decode(res.body)['data']?['FunctionResult'];
      if (data != null && data['roomId'] != null) {
        final betAmt = int.tryParse(data['betAmount']?.toString() ?? '50') ?? 50;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreGameScreen(
              sessionTicket: widget.sessionTicket,
              roomId: data['roomId'].toString(),
              myPlayFabId: widget.playFabId,
              myName: playfabUsername,
              myTrophies: trophies,
              opponentName: senderUsername,
              opponentId: senderId,
              opponentTrophies: 0,
              betAmount: betAmt,
            ),
          ),
        ).then((_) { if (mounted) _fetchPlayerData(); });
      }
    }
  }

  Future<void> _sendFriendRequest() async {
    final friendUsername = _friendAddController.text.trim();
    if (friendUsername.isEmpty || friendUsername.toLowerCase() == playfabUsername.toLowerCase()) return; 

    setState(() { _isAddingFriend = true; });
    const titleId = "1A15A2"; 

    try {
      final accountUrl = Uri.parse('https://$titleId.playfabapi.com/Client/GetAccountInfo');
      final accountRes = await http.post(accountUrl, headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket}, body: json.encode({"Username": friendUsername}));
      final accountData = json.decode(accountRes.body);

      if (accountRes.statusCode != 200) {
        setState(() { _isAddingFriend = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("שם משתמש לא קיים.", textAlign: TextAlign.right), backgroundColor: Colors.redAccent));
        return;
      }

      final targetPlayFabId = accountData['data']['AccountInfo']['PlayFabId'];
      final url = Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript');
      final response = await http.post(url, headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket}, body: json.encode({"FunctionName": "SendFriendRequest", "FunctionParameter": {"TargetPlayFabId": targetPlayFabId, "TargetUsername": friendUsername}}));
      setState(() { _isAddingFriend = false; });

      if (response.statusCode == 200) {
        _friendAddController.clear(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("בקשת החברות נשלחה!", textAlign: TextAlign.right), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() { _isAddingFriend = false; });
    }
  }

  Future<void> _handleFriendRequest(String requesterUsername, int index, StateSetter setStateDialog, bool isAccept) async {
    const titleId = "1A15A2"; 
    final url = Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket}, body: json.encode({"FunctionName": isAccept ? "AcceptFriendRequest" : "DeclineFriendRequest", "FunctionParameter": {"RequesterUsername": requesterUsername}}));
      if (response.statusCode == 200) {
        setStateDialog(() { friendRequests.removeAt(index); });
        setState(() { friendRequests.removeWhere((req) => req["username"] == requesterUsername); });
        if (isAccept) _fetchPlayerData(); 
      }
    } catch (e) {}
  }

  void _showSettingsMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent, 
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).size.height * 0.12, left: MediaQuery.of(context).size.width * 0.02, 
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.25, padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.grey, width: 2)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuButton("מי אנחנו", () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen())); }),
                      _buildMenuButton("עדכון פרטים אישיים", () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("בקרוב...", textAlign: TextAlign.right)));
                      }),
                      _buildMenuButton("תמיכה", () => _showSupportDialog()),
                      _buildMenuButton("תקנון", () => _showTermsDialog()),
                      _buildMenuButton("התנתק", () { Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthScreen()), (Route<dynamic> route) => false); }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuButton(String text, VoidCallback onTap) {
    return Container(width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 1)), child: Material(color: Colors.black, child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)))))));
  }

  void _showFriendRequestsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final size = MediaQuery.of(context).size;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: size.width * 0.5, constraints: BoxConstraints(maxHeight: size.height * 0.8), padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: const Color(0xFFC4E4F5), border: Border.all(color: Colors.white, width: 3)),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(alignment: Alignment.topLeft, child: IconButton(icon: const Icon(Icons.close, size: 28, color: Colors.black), onPressed: () => Navigator.of(ctx).pop())),
                        const Text("בקשות חברות", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                      ],
                    ),
                    const Divider(color: Colors.white, thickness: 2),
                    if (friendRequests.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Text("אין בקשות חדשות", style: TextStyle(fontSize: 20, fontStyle: FontStyle.italic)))
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: friendRequests.length,
                          itemBuilder: (context, index) {
                            final requestUsername = friendRequests[index]["username"] ?? "שחקן";
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  SizedBox(height: 30, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: () { _handleFriendRequest(requestUsername, index, setStateDialog, false); }, child: const Text("מחיקה", style: TextStyle(color: Colors.white, fontSize: 12)))),
                                  const SizedBox(width: 8),
                                  SizedBox(height: 30, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: () { _handleFriendRequest(requestUsername, index, setStateDialog, true); }, child: const Text("אישור", style: TextStyle(color: Colors.white, fontSize: 12)))),
                                  const Spacer(),
                                  Text(requestUsername, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showSupportDialog() {
    final nameController = TextEditingController(text: playfabUsername);
    final emailController = TextEditingController(text: userEmail);
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final size = MediaQuery.of(context).size;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: size.width * 0.6, 
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A8D9B).withOpacity(0.95), 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(icon: const Icon(Icons.close, size: 28, color: Colors.black54), onPressed: () { Navigator.of(ctx).pop(); Navigator.of(context).pop(); }),
                          ),
                          const Text("תמיכה", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          const SizedBox(width: 40, child: Text("שם", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), 
                          Expanded(child: _buildSupportTextField(nameController))
                        ]
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const SizedBox(width: 40, child: Text("מייל", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), 
                          Expanded(child: _buildSupportTextField(emailController))
                        ]
                      ),
                      const SizedBox(height: 15),
                      _buildSupportTextField(messageController, maxLines: 4),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                        onPressed: () async {
                          if (messageController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("אנא כתוב הודעה.", textAlign: TextAlign.right))); return; }
                          final subject = Uri.encodeComponent('פנייה מ-${nameController.text} דרך BeshLeague');
                          final body = Uri.encodeComponent('שם: ${nameController.text}\nמייל: ${emailController.text}\n\nהודעה:\n${messageController.text}');
                          final emailUri = Uri.parse('mailto:support@beshleague.com?subject=$subject&body=$body');
                          final nav1 = Navigator.of(ctx);
                          final nav2 = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(emailUri);
                            nav1.pop(); nav2.pop();
                            messenger.showSnackBar(const SnackBar(content: Text("אפליקציית המייל נפתחה!", textAlign: TextAlign.right), backgroundColor: Colors.green));
                          } else {
                            messenger.showSnackBar(const SnackBar(content: Text("לא ניתן לפתוח אפליקציית מייל.", textAlign: TextAlign.right), backgroundColor: Colors.redAccent));
                          }
                        },
                        child: const Text("שלח", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: size.width * 0.6, 
            height: size.height * 0.8, 
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFF7A8D9B).withOpacity(0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2)),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(alignment: Alignment.topLeft, child: IconButton(icon: const Icon(Icons.close, size: 28, color: Colors.black54), onPressed: () { Navigator.of(ctx).pop(); Navigator.of(context).pop(); })),
                    const Text("תקנון", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.black54, thickness: 1),
                const SizedBox(height: 5),
                Expanded(
                  child: Markdown(
                    data: termsOfServiceMarkdown, 
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5), 
                      strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black), 
                      h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, height: 1.5), 
                      h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black), 
                      listBullet: const TextStyle(fontSize: 14, color: Colors.white), 
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Icon(Icons.arrow_downward, color: Colors.white, size: 24),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSupportTextField(TextEditingController controller, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.5)),
      child: TextField(
        controller: controller, 
        maxLines: maxLines, 
        textAlign: TextAlign.right, 
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          border: InputBorder.none, 
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl, // מגדיר את כל המסך מימין לשמאל
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final safePadding = MediaQuery.of(context).padding;

            return Stack(
            children: [
              Image.asset('assets/background_light.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity),
              
              // --- חסימת המסך עד לטעינה מלאה ---
              if (isLoadingData)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.amber, strokeWidth: 5),
                      SizedBox(height: 20),
                      Text("טוען את הנתונים...", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    // הפס השחור למעלה כולל שוליים בטוחים (נצמד לקצה העליון)
                    _buildTopBar(width, height, safePadding),
                    
                    Expanded(
                      child: Stack(
                        children: [
                          // כפתורי חנות/ליגות/שחק צמודים שמאלה
                          Positioned(
                            left: 10,
                            top: height * 0.02,
                            bottom: height * 0.02,
                            child: SizedBox(width: width * 0.12, child: _buildLeftMenu(width, height))
                          ),
                          // פרופיל באמצע, קצת מורם למעלה
                          Align(
                            alignment: const Alignment(0.0, -0.6),
                            child: SizedBox(width: width * 0.45, child: _buildCenterProfile(width, height))
                          ),
                          // כפתור חברים (מוצג כשהפאנל סגור)
                          if (!_isFriendsPanelOpen)
                            Positioned(
                              right: 10,
                              top: height * 0.02,
                              child: GestureDetector(
                                onTap: () => setState(() => _isFriendsPanelOpen = true),
                                child: _buildFriendsButton(height),
                              ),
                            ),
                          // פאנל חברים צף (מוצג כשפתוח)
                          if (_isFriendsPanelOpen)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: SizedBox(width: width * 0.28, child: _buildFriendsPanel(width, height)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          );
          },
        ),
      ),
    );
  }

  void _showDailyGiftDialog() {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final alreadyClaimed = _lastStreakDate == today;
    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        final displayStreak = alreadyClaimed ? streakDays : (streakDays == 0 ? 1 : streakDays);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: size.width * 0.55,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 26),
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const Text("מתנת כניסה יומית", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStreakDay(1, 50, displayStreak),
                    _buildStreakDay(2, 100, displayStreak),
                    _buildStreakDay(3, 150, displayStreak),
                    _buildStreakDay(4, 200, displayStreak),
                  ],
                ),
                const SizedBox(height: 8),
                const Text("יום 4+ = 200 מטבעות בכל יום", style: TextStyle(fontSize: 11, color: Colors.white54)),
                const SizedBox(height: 16),
                if (alreadyClaimed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                    child: const Text("כבר קיבלת מתנה היום ✓", style: TextStyle(fontSize: 16, color: Colors.greenAccent)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _claimDailyGift();
                    },
                    child: const Text("קבל מתנה!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreakDay(int day, int reward, int currentStreak) {
    final isActive = currentStreak >= day;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isActive ? Colors.amber : Colors.white12,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? Colors.orange : Colors.white24, width: 2),
          ),
          child: Center(
            child: Icon(Icons.card_giftcard, color: isActive ? Colors.black : Colors.white38, size: 26),
          ),
        ),
        const SizedBox(height: 4),
        Text("יום $day", style: TextStyle(fontSize: 11, color: isActive ? Colors.amber : Colors.white54)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, size: 11, color: isActive ? Colors.amber : Colors.white38),
            const SizedBox(width: 2),
            Text("$reward", style: TextStyle(fontSize: 11, color: isActive ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Future<void> _claimDailyGift() async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    if (_lastStreakDate == today) return;

    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    int newStreak;
    if (_lastStreakDate == yesterday) {
      newStreak = streakDays + 1;
    } else {
      newStreak = 1;
    }
    final reward = newStreak >= 4 ? 200 : newStreak * 50;

    setState(() {
      streakDays = newStreak;
      _lastStreakDate = today;
      coins += reward;
    });

    const titleId = "1A15A2";
    final headers = {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket};
    try {
      await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/AddUserVirtualCurrency'),
        headers: headers,
        body: json.encode({"VirtualCurrency": "CO", "Amount": reward}),
      );
      await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/UpdateUserData'),
        headers: headers,
        body: json.encode({
          "Data": {
            "StreakDays": "$newStreak",
            "LastStreakDate": today,
          }
        }),
      );
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("קיבלת $reward מטבעות! רצף: $newStreak ימים 🎁", textAlign: TextAlign.right),
          backgroundColor: Colors.amber[800],
        ),
      );
    }
  }

  Widget _buildTopBar(double width, double height, EdgeInsets safePadding) {
    final barH = (height * 0.055).clamp(28.0, 42.0);   // shorter bar
    final fs = (height * 0.038).clamp(12.0, 16.0);      // larger font
    final iconSz = (height * 0.050).clamp(20.0, 26.0);  // larger icons
    return Container(
      width: double.infinity,
      height: barH + safePadding.top,
      color: Colors.black,
      padding: EdgeInsets.only(top: safePadding.top, left: width * 0.015, right: width * 0.015),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(playfabUsername, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.bold))),
          Text("ליגה - בקרוב", style: TextStyle(color: Colors.white54, fontSize: fs * 0.85, fontStyle: FontStyle.italic)),
          Row(children: [Icon(Icons.monetization_on, color: Colors.amber, size: iconSz), const SizedBox(width: 3), Text("$coins", style: TextStyle(color: Colors.white, fontSize: fs))]),
          Row(children: [Icon(Icons.emoji_events, color: Colors.amber, size: iconSz), const SizedBox(width: 3), Text("$trophies", style: TextStyle(color: Colors.white, fontSize: fs))]),
          IconButton(icon: Icon(Icons.settings, color: Colors.white, size: iconSz), onPressed: _showSettingsMenu, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white, size: iconSz),
            onPressed: _showDailyGiftDialog,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Image.asset('assets/logo.png', height: barH * 0.85),
        ],
      ),
    );
  }

Widget _buildLeftMenu(double width, double height) {
    final buttonSize = height * 0.12; 
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            _buildSquareMenuButton(Icons.storefront, const Color(0xFF6AE070), buttonSize),
            SizedBox(height: height * 0.02),
            _buildSquareMenuButton(Icons.emoji_events, const Color(0xFFFFB74D), buttonSize),
            SizedBox(height: height * 0.02),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("מלאי - בקרוב!", textAlign: TextAlign.right))),
              child: _buildSquareMenuButton(Icons.inventory_2, const Color(0xFF64B5F6), buttonSize),
            ),
          ],
        ),
        Column(
          children: [
            // --- כפתור צפייה בווידאו (באותו גובה של כפתור שחק) ---
            Container(
              width: double.infinity, height: height * 0.16,
              decoration: BoxDecoration(color: const Color(0xFFB4F0C0), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 4)]),
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("צפייה בסרטון - בקרוב!", textAlign: TextAlign.right)));
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.monetization_on, color: Colors.amber, size: 14), SizedBox(width: 2), Text("+50", style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 2),
                      const Icon(Icons.ondemand_video, size: 28, color: Colors.black87),
                      const Text("צפה", style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                    ]
                  )
                ),
              ),
            ),
            SizedBox(height: height * 0.02),
            
            // --- כפתור שחק ---
            Container(
              width: double.infinity, height: height * 0.16,
              decoration: BoxDecoration(gradient: LinearGradient(colors: _isNavigatingToGame ? [Colors.grey.shade600, Colors.grey.shade700] : [const Color(0xFFE040FB), const Color(0xFF536DFE)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2)),
              child: InkWell(
                onTap: () async {
                   if (_isNavigatingToGame) return;
                   if (coins < 50) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("אין לך מספיק מטבעות למשחק. (נדרש 50)", textAlign: TextAlign.right), backgroundColor: Colors.redAccent));
                     return;
                   }
                   setState(() { _isNavigatingToGame = true; });
                   await Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => PreGameScreen(
                         sessionTicket: widget.sessionTicket,
                         roomId: "",
                         myPlayFabId: widget.playFabId,
                         myName: playfabUsername,
                         myTrophies: trophies,
                         opponentId: "",
                         opponentName: "",
                         opponentTrophies: 0,
                         betAmount: 50,
                         isRandomMatch: true,
                       )
                     )
                   );
                   if (mounted) {
                     setState(() { _isNavigatingToGame = false; });
                     _fetchPlayerData(); // refresh coins/XP after returning from game
                   }
                },
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("שחק", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.monetization_on, color: Colors.amber, size: 16), SizedBox(width: 3), Text("50", style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold))]),
                ])),
              ),
            ),
          ],
        ),
      ],
    );
  }
 
  Widget _buildFriendsButton(double height) {
    final size = height * 0.12;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFC4E4F5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: Icon(Icons.people, size: size * 0.5, color: Colors.black87),
        ),
        if (friendRequests.isNotEmpty)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text('${friendRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildSquareMenuButton(IconData icon, Color color, double size) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black, width: 2)), child: Icon(icon, size: size * 0.5, color: Colors.black));
  }

  Widget _buildXpBar() {
    // Exponential formula: xpNeeded = 100 * level^1.5
    int level = 1;
    int acc = 0;
    while (true) {
      final needed = (100 * pow(level, 1.5)).round();
      if (acc + needed > xp) break;
      acc += needed;
      level++;
      if (level > 200) break;
    }
    final xpNeededThisLevel = (100 * pow(level, 1.5)).round();
    final xpInLevel = xp - acc;
    final progress = xpNeededThisLevel > 0 ? (xpInLevel / xpNeededThisLevel).clamp(0.0, 1.0) : 0.0;
    final boostRemaining = (5 - dailyGamesPlayed).clamp(0, 5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.star, color: Colors.orange, size: 13),
                const SizedBox(width: 4),
                Text("רמה $level", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
              ]),
              Text("$xpInLevel / $xpNeededThisLevel XP", style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[700],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              minHeight: 9,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 12),
              const SizedBox(width: 3),
              Text(
                boostRemaining > 0 ? "בונוס XP x2: נותרו $boostRemaining משחקים היום" : "בונוס יומי נוצל",
                style: TextStyle(fontSize: 9, color: boostRemaining > 0 ? Colors.amber : Colors.white38),
              ),
              const SizedBox(width: 6),
              ...List.generate(5, (i) => Icon(
                i < dailyGamesPlayed.clamp(0, 5) ? Icons.star : Icons.star_border,
                color: i < dailyGamesPlayed.clamp(0, 5) ? Colors.orange : Colors.white30,
                size: 11,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterProfile(double width, double height) {
    final avatarR = height * 0.09;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile picture
              Container(
                width: avatarR * 2,
                height: avatarR * 2,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 2.5),
                ),
                child: Icon(Icons.person, size: avatarR * 1.1, color: Colors.grey[300]),
              ),
              const SizedBox(height: 6),
              // Username
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(playfabUsername, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              // XP bar
              _buildXpBar(),
              const SizedBox(height: 12),
              // Wins / Losses / Trophies row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBadge(Icons.emoji_events_outlined, "$totalWins", "נצחונות", Colors.greenAccent),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _buildStatBadge(Icons.close, "$totalLosses", "הפסדים", Colors.redAccent),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _buildStatBadge(Icons.emoji_events, "$trophies", "גביעים", Colors.amber),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }

  Widget _buildFriendsPanel(double width, double height) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFC4E4F5), border: Border.all(color: Colors.white, width: 3)),
      child: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 5), color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text("חברים", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Positioned(left: 5, child: Stack(children: [IconButton(icon: const Icon(Icons.person_add_alt_1, size: 24, color: Colors.black), onPressed: _showFriendRequestsDialog), if (friendRequests.isNotEmpty) Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${friendRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))])),
                Positioned(right: 5, child: IconButton(icon: const Icon(Icons.close, size: 24, color: Colors.black), onPressed: () => setState(() => _isFriendsPanelOpen = false))),
              ],
            ),
          ),
          const Divider(color: Colors.white, thickness: 3, height: 0),
          Expanded(
            child: isLoadingData
                ? const Center(child: CircularProgressIndicator(color: Colors.black)) 
                : friendsList.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(10.0), child: Text("אין חברים ברשימה", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
                    : ListView.builder(
                        itemCount: friendsList.length,
                        itemBuilder: (context, index) {
                          final friend = friendsList[index];
                          final friendName = friend["Username"] ?? "שחקן";
                          final friendPlayFabId = friend["FriendPlayFabId"];
                          bool isOnline = onlineFriendIds.contains(friendPlayFabId); 

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              children: [
                                if (isOnline)
                                  SizedBox(height: 30, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28559A), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: () => _showDuelInviteDialog(friendName), child: const Text("הזמן", style: TextStyle(color: Colors.white, fontSize: 12))))
                                else
                                  const SizedBox(width: 55), 
                                const Spacer(),
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.redAccent, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Flexible(child: Text(friendName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const Divider(color: Colors.white, thickness: 3, height: 0),
          Padding(padding: const EdgeInsets.all(8), child: Column(children: [const Text("הוסף לפי שם משתמש", style: TextStyle(fontSize: 14)), const SizedBox(height: 5), Row(children: [SizedBox(height: 30, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28559A), padding: const EdgeInsets.symmetric(horizontal: 8)), onPressed: _isAddingFriend ? null : _sendFriendRequest, child: _isAddingFriend ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("שלח בקשה", style: TextStyle(color: Colors.white, fontSize: 12)))), const SizedBox(width: 5), Expanded(child: Container(height: 30, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black)), child: TextField(controller: _friendAddController, textAlign: TextAlign.right, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 15, right: 5), isDense: true))))])])),
        ],
      ),
    );
  }
}
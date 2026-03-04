import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart'; 
import 'package:besh_league/screens/auth_screen.dart';
import 'package:besh_league/screens/about_screen.dart'; 
import 'package:besh_league/screens/pre_game_screen.dart'; 
import 'package:besh_league/screens/game_board_screen.dart';

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
  
  int coins = 0;
  int trophies = 0; 
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
        body: json.encode({"Keys": ["FriendRequests", "DuelRequests", "DuelStatus", "CurrentLogin", "PreviousLogin"]})
      );
      
      List<dynamic> fetchedRequests = [];
      List<dynamic> fetchedDuelRequests = [];
      Map<String, dynamic>? duelStatus;
      String savedCurrentLogin = "";
      String savedPreviousLogin = "";

      if (userDataRes.statusCode == 200) {
        final userData = json.decode(userDataRes.body)['data']?['Data'];
        if (userData != null) {
          if (userData['FriendRequests'] != null) fetchedRequests = json.decode(userData['FriendRequests']['Value']);
          if (userData['DuelRequests'] != null) fetchedDuelRequests = json.decode(userData['DuelRequests']['Value']);
          if (userData['DuelStatus'] != null) duelStatus = json.decode(userData['DuelStatus']['Value']);
          
          if (userData['CurrentLogin'] != null) savedCurrentLogin = userData['CurrentLogin']['Value'];
          if (userData['PreviousLogin'] != null) savedPreviousLogin = userData['PreviousLogin']['Value'];
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
                  myName: playfabUsername,
                  myTrophies: trophies,
                  opponentName: duelStatus!['opponent'].toString(),
                  opponentTrophies: 0, 
                  betAmount: acceptedBet,
                ),
              ),
            );
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
    await http.post(
      Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
      headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
      body: json.encode({
        "FunctionName": "RespondDuelInvite",
        "FunctionParameter": { "SenderUsername": senderUsername, "SenderId": senderId, "IsAccept": isAccept }
      }),
    );
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
        bool isSending = false; 

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
                        onPressed: isSending ? null : () async {
                          if (messageController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("אנא כתוב הודעה.", textAlign: TextAlign.right))); return; }
                          setStateDialog(() => isSending = true); 
                          try {
                            final response = await http.post(Uri.parse('https://formspree.io/f/YOUR_FORM_ID_HERE'), headers: {'Content-Type': 'application/json'}, body: json.encode({'name': nameController.text, 'email': emailController.text, 'message': messageController.text}));
                            setStateDialog(() => isSending = false);
                            if (response.statusCode == 200 || response.statusCode == 201) {
                              Navigator.of(ctx).pop(); Navigator.of(context).pop(); 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ההודעה נשלחה בהצלחה!", textAlign: TextAlign.right), backgroundColor: Colors.green));
                            }
                          } catch (e) { setStateDialog(() => isSending = false); }
                        },
                        child: isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("שלח", style: TextStyle(color: Colors.white, fontSize: 16)),
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

  Widget _buildTableCell(String text, bool isHeader) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: Center(child: Text(text, style: TextStyle(fontSize: isHeader ? 12 : 16, fontWeight: FontWeight.bold, color: Colors.black))));
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
                
                Column(
                  children: [
                    // הפס השחור למעלה כולל שוליים בטוחים (נצמד לקצה העליון)
                    _buildTopBar(width, height, safePadding),
                    
                    Expanded(
                      child: Stack(
                        children: [
                          // פאנל חברים צמוד ימינה לגמרי
                          Positioned(
                            right: 0, 
                            top: 0, 
                            bottom: 0, 
                            child: SizedBox(width: width * 0.28, child: _buildFriendsPanel(width, height))
                          ),
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

  Widget _buildTopBar(double width, double height, EdgeInsets safePadding) {
    return Container(
      width: double.infinity, height: height * 0.12 + safePadding.top, color: Colors.black, padding: EdgeInsets.only(top: safePadding.top, left: width * 0.02, right: width * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(playfabUsername, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("סטטוס ליגה - (אני מעדכנת)", style: TextStyle(color: Colors.white, fontSize: 16)),
          Row(children: [const Icon(Icons.monetization_on, color: Colors.amber, size: 24), const SizedBox(width: 5), Text("$coins מטבעות", style: const TextStyle(color: Colors.white, fontSize: 16))]),
          Row(children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 24), const SizedBox(width: 5), Text("$trophies גביעים", style: const TextStyle(color: Colors.white, fontSize: 16))]),
          IconButton(icon: const Icon(Icons.settings, color: Colors.white, size: 28), onPressed: _showSettingsMenu),
          Image.asset('assets/logo.png', height: height * 0.08),
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
            _buildSquareMenuButton(Icons.calendar_month, const Color(0xFFFFB74D), buttonSize),
          ],
        ),
        Container(
          width: double.infinity, height: height * 0.16,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF536DFE)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2)),
          // הוספנו פה מעבר לעמוד המשחק למטרות סימולציה/בדיקה כשלוחצים "שחק"
          child: InkWell(
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const GameBoardScreen()));
            },
            child: const Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.all(8.0), child: Text("שחק", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))))),
          ),
        ),
      ],
    );
  }

  Widget _buildSquareMenuButton(IconData icon, Color color, double size) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black, width: 2)), child: Icon(icon, size: size * 0.5, color: Colors.black));
  }

  Widget _buildCenterProfile(double width, double height) {
    return Column(
      mainAxisSize: MainAxisSize.min, // קריטי כדי שהפרופיל לא יימתח על כל המסך
      children: [
        Container(
          width: double.infinity, height: height * 0.55, decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(clipBehavior: Clip.none, children: [Container(width: height * 0.16, height: height * 0.16, decoration: BoxDecoration(color: Colors.grey[400], border: Border.all(color: Colors.white, width: 3)), child: Icon(Icons.person, size: height * 0.1, color: Colors.grey[600])), Positioned(bottom: -5, right: -10, child: Row(children: const [Icon(Icons.favorite, color: Colors.blueAccent, size: 16), Icon(Icons.favorite, color: Colors.purple, size: 24)]))]),
                  const SizedBox(width: 15),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FittedBox(fit: BoxFit.scaleDown, child: Text(playfabUsername, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black))), const SizedBox(height: 2), FittedBox(fit: BoxFit.scaleDown, child: Text("התחברות אחרונה - $lastLogin", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))), const SizedBox(height: 8), FittedBox(fit: BoxFit.scaleDown, child: Text("השתתפות בליגות: $leaguesPlayed", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)))])),
                ],
              ),
              const Spacer(),
              Container(width: width * 0.25, color: Colors.white, child: Table(border: TableBorder.all(color: Colors.black, width: 2), children: [TableRow(children: [_buildTableCell("נצחונות", true), _buildTableCell("הפסדים", true)]), TableRow(children: [_buildTableCell("$totalWins", false), _buildTableCell("$totalLosses", false)])])),
              const Spacer(),
              Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 35), const SizedBox(width: 10), Text("X  $trophies", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black))])),
            ],
          ),
        ),
        SizedBox(height: height * 0.05), // מרווח יחסי
        Container(
          width: width * 0.35, height: height * 0.12, decoration: BoxDecoration(color: const Color(0xFFB4F0C0), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 4)]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.ondemand_video, size: 30), const SizedBox(width: 8), Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Text("קבל 50 מטבעות", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text("נותרו 2 צפיות", style: TextStyle(fontSize: 12))])]),
        ),
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
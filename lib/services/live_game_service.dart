import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LiveGameService {
  final String sessionTicket;
  final String roomId;
  final String titleId = "1A15A2"; 

  Timer? _pollingTimer;
  
  // זה הצינור שדרכו מסך הלוח יקבל עדכונים חיים מהשרת
  final StreamController<Map<String, dynamic>> _gameStateController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get gameStateStream => _gameStateController.stream;

  LiveGameService({required this.sessionTicket, required this.roomId});

  // 1. התחלת ההאזנה לשרת (Polling)
  void startListening() {
    // דוגמים את השרת כל 1.5 שניות
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _fetchRoomData();
    });
  }

  // 2. קבלת הנתונים מהחדר ב-PlayFab
  Future<void> _fetchRoomData() async {
    final url = Uri.parse('https://$titleId.playfabapi.com/Client/GetSharedGroupData');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': sessionTicket,
        },
        body: json.encode({
          "SharedGroupId": roomId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final data = responseData['data']?['Data'];
        if (data != null) {
          // שולחים את המידע המעודכן לצינור כדי שהמסך יתרענן
          _gameStateController.add(data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      // כאן אפשר לטפל בשגיאות תקשורת (למשל אם שחקן התנתק מהאינטרנט)
    }
  }

  // 3. שליחת נתונים לחדר (למשל כשאת זורקת קוביות או מזיזה כלי)
  Future<void> updateGameState(Map<String, String> updates) async {
    final url = Uri.parse('https://$titleId.playfabapi.com/Client/UpdateSharedGroupData');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': sessionTicket,
        },
        body: json.encode({
          "SharedGroupId": roomId,
          "Data": updates, // המידע שאנחנו מעדכנים (למשל {"player1_roll": "6"})
        }),
      );
    } catch (e) {
      print("שגיאה בעדכון השרת: $e");
    }
  }
// 4. סגירת החדר בשרת (למחוק אותו כדי שלא יתפוס מקום)
  Future<void> closeRoom() async {
    final url = Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': sessionTicket,
        },
        body: json.encode({
          "FunctionName": "DeleteMatchRoom",
          "FunctionParameter": { "RoomId": roomId }
        }),
      );
    } catch (e) {
      print("שגיאה בסגירת החדר: $e");
    }
  }
  // 4. סגירת החיבור כשיוצאים מהמשחק
  void dispose() {
    _pollingTimer?.cancel();
    _gameStateController.close();
  }
}
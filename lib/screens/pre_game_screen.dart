import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'game_board_screen.dart';

class PreGameScreen extends StatefulWidget {
  final String sessionTicket;
  final String roomId;
  final String myPlayFabId;
  final String myName;
  final int myTrophies;
  final String opponentId;
  final String opponentName;
  final int opponentTrophies;
  final int betAmount;
  final bool isRandomMatch; 

  const PreGameScreen({
    super.key,
    this.sessionTicket = "",
    this.roomId = "",
    this.myPlayFabId = "me_123",
    this.myName = "אני",
    this.myTrophies = 10,
    this.opponentId = "opp_456",
    this.opponentName = "יריב",
    this.opponentTrophies = 15,
    this.betAmount = 50,
    this.isRandomMatch = false,
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

  int searchCountdown = 20;
  bool isSearching = false;
  Timer? _searchTimer;
  String currentOpponentName = "";
  String currentOpponentId = "";
  int currentOpponentTrophies = 0;
  String _activeRoomId = "";

  @override
  void initState() {
    super.initState();
    currentOpponentName = widget.opponentName;
    currentOpponentId = widget.opponentId;
    currentOpponentTrophies = widget.opponentTrophies;
    _activeRoomId = widget.roomId;

    if (widget.isRandomMatch && currentOpponentId.isEmpty) {
      isSearching = true;
      _startMatchmakingSearch();
    } else if (_activeRoomId.isNotEmpty && widget.sessionTicket.isNotEmpty) {
      _initRoomAndListen();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollingTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _startMatchmakingSearch() async {
    const titleId = "1A15A2"; 
    try {
      final res = await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"FunctionName": "JoinMatchmaking"}),
      );
      final data = json.decode(res.body)['data']?['FunctionResult'];
      
      if (data != null && data['status'] == 'matched') {
        _setupMatchedOpponent(data['opponentId'], data['roomId']);
        return;
      }
    } catch (e) {}

    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (searchCountdown > 1) {
        setState(() { searchCountdown--; });
        if (searchCountdown % 2 == 0) _checkIfSomeoneFoundMe();
      } else {
        timer.cancel();
        _cancelMatchmaking();
        Navigator.pop(context, 'timeout'); 
      }
    });
  }

  Future<void> _checkIfSomeoneFoundMe() async {
    if (!isSearching) return;
    const titleId = "1A15A2"; 
    try {
      final res = await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"FunctionName": "CheckMatchmaking"}),
      );
      final data = json.decode(res.body)['data']?['FunctionResult'];
      if (data != null && data['status'] == 'matched') {
        _searchTimer?.cancel();
        _setupMatchedOpponent(data['opponentId'], data['roomId']);
      }
    } catch (e) {}
  }

  Future<void> _setupMatchedOpponent(String oppId, String roomId) async {
    const titleId = "1A15A2"; 
    try {
      final accountRes = await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/GetAccountInfo'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"PlayFabId": oppId}),
      );
      final accountData = json.decode(accountRes.body);
      final oppName = accountData['data']['AccountInfo']['Username'] ?? "שחקן אקראי";

      if (mounted) {
        setState(() {
          currentOpponentId = oppId;
          currentOpponentName = oppName;
          _activeRoomId = roomId; 
          isSearching = false; 
        });
        _initRoomAndListen(); 
      }
    } catch (e) {}
  }

  void _cancelMatchmaking() {
    const titleId = "1A15A2"; 
    http.post(
      Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
      headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
      body: json.encode({"FunctionName": "CancelMatchmaking"}),
    );
  }

  Future<void> _initRoomAndListen() async {
    const titleId = "1A15A2"; 
    if (!widget.isRandomMatch) {
      try {
        await http.post(
          Uri.parse('https://$titleId.playfabapi.com/Client/ExecuteCloudScript'),
          headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
          body: json.encode({"FunctionName": "CreateMatchRoom", "FunctionParameter": { "OpponentId": currentOpponentId }}),
        );
      } catch (e) {}
    }

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
        body: json.encode({ "SharedGroupId": _activeRoomId, "Keys": ["${widget.myPlayFabId}_ready", "${currentOpponentId}_ready"] }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data']?['Data'];
        if (data != null) {
          bool opponentR = data["${currentOpponentId}_ready"] != null && data["${currentOpponentId}_ready"]["Value"] == "true";
          bool meR = data["${widget.myPlayFabId}_ready"] != null && data["${widget.myPlayFabId}_ready"]["Value"] == "true";
          
          if (mounted && opponentR != isOpponentReady) setState(() { isOpponentReady = opponentR; });

          if (meR && opponentR && !isCountingDown) _startCountdownAndGo();
        }
      }
    } catch (e) {}
  }

  Future<void> _setReady() async {
    setState(() { isMeReady = true; });
    
    if (widget.sessionTicket.isNotEmpty && _activeRoomId.isNotEmpty) {
      const titleId = "1A15A2"; 
      await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/UpdateSharedGroupData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"SharedGroupId": _activeRoomId, "Data": { "${widget.myPlayFabId}_ready": "true" }}),
      );
    } else {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) { setState(() { isOpponentReady = true; }); if (!isCountingDown) _startCountdownAndGo(); }
      });
    }
  }

  void _startCountdownAndGo() {
    _pollingTimer?.cancel();
    setState(() { isCountingDown = true; });
      
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        setState(() { countdown--; });
      } else {
        timer.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => GameBoardScreen(
            sessionTicket: widget.sessionTicket,
            roomId: _activeRoomId,
            myPlayFabId: widget.myPlayFabId,
            myName: widget.myName,
            myTrophies: widget.myTrophies,
            opponentId: currentOpponentId,
            opponentName: currentOpponentName,
            opponentTrophies: currentOpponentTrophies,
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
        textDirection: TextDirection.rtl,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return Stack(
              children: [
                Image.asset('assets/background_dark.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0A192F))),
                
                Positioned(
                  top: height * 0.05, right: width * 0.03, 
                  child: GestureDetector(
                    onTap: () {
                      if (isSearching) _cancelMatchmaking();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFB73E3E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2)),
                      child: const Text("לפרוש", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),

                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.05, vertical: height * 0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPlayerColumn(width: width, height: height, name: widget.myName, trophies: widget.myTrophies, isMe: true, isReady: isMeReady),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("VS", style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                            SizedBox(height: height * 0.02),
                            Row(children: [const Icon(Icons.monetization_on, color: Colors.amber, size: 50), const SizedBox(width: 10), Text("$totalPot", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white))]),
                            SizedBox(height: height * 0.05),
                            Stack(clipBehavior: Clip.none, children: [const Icon(Icons.chat_bubble, color: Colors.greenAccent, size: 50), Positioned(right: -15, bottom: -10, child: Icon(Icons.chat_bubble, color: Colors.grey[300], size: 40))]),
                          ],
                        ),
                        isSearching ? _buildSearchingColumn(height) : _buildPlayerColumn(width: width, height: height, name: currentOpponentName, trophies: currentOpponentTrophies, isMe: false, isReady: isOpponentReady),
                      ],
                    ),
                  ),
                ),

                if (isCountingDown)
                  Container(
                    color: Colors.black.withOpacity(0.7), width: double.infinity, height: double.infinity,
                    child: Center(child: Text("$countdown", style: const TextStyle(fontSize: 150, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.blueAccent, blurRadius: 20)]))),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerColumn({required double width, required double height, required String name, required int trophies, required bool isMe, required bool isReady}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(width: height * 0.35, height: height * 0.35, decoration: BoxDecoration(color: Colors.grey[400], border: Border.all(color: Colors.white, width: 4)), child: Icon(Icons.person, size: height * 0.25, color: Colors.grey[600])),
            Positioned(bottom: -10, right: -15, child: Row(children: const [Icon(Icons.favorite, color: Colors.blueAccent, size: 25), Icon(Icons.favorite, color: Colors.purple, size: 40)])),
          ],
        ),
        SizedBox(height: height * 0.05),
        Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: height * 0.01),
        Row(children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 30), const SizedBox(width: 10), Text("$trophies", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))]),
        SizedBox(height: height * 0.01),
        Row(children: [const Icon(Icons.monetization_on, color: Colors.amber, size: 30), const SizedBox(width: 10), Text("${widget.betAmount}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))]),
        SizedBox(height: height * 0.05),
        SizedBox(height: height * 0.12, child: isReady ? _buildReadySticker() : _buildStatusButton(isMe, width, height)),
      ],
    );
  }

  Widget _buildSearchingColumn(double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: height * 0.35, height: height * 0.35,
          decoration: BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 4)),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.amber),
                const SizedBox(height: 15),
                Text("$searchCountdown", style: const TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ),
        SizedBox(height: height * 0.05),
        const Text("מחפש יריב...", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white70)),
      ],
    );
  }

  Widget _buildReadySticker() {
    return Stack(
      children: [
        Text("READY", style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, letterSpacing: 3, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 10..color = Colors.black)),
        const Text("READY", style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, letterSpacing: 3, color: Color(0xFFA8E6CF))),
      ],
    );
  }

  Widget _buildStatusButton(bool isMe, double width, double height) {
    if (isMe) {
      return GestureDetector(
        onTap: isSearching ? null : _setReady, 
        child: Container(width: width * 0.15, decoration: BoxDecoration(color: isSearching ? Colors.grey : const Color(0xFF9DE05C), borderRadius: BorderRadius.circular(20)), child: const Center(child: Text("מוכן", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)))),
      );
    } else {
      return GestureDetector(
        onTap: widget.sessionTicket.isEmpty ? () { setState(() { isOpponentReady = true; }); if (isMeReady && !isCountingDown) _startCountdownAndGo(); } : null,
        child: Container(width: width * 0.15, decoration: BoxDecoration(color: const Color(0xFF5A667D), borderRadius: BorderRadius.circular(20)), child: const Center(child: Text("בהמתנה", style: TextStyle(fontSize: 22, color: Colors.white70)))),
      );
    }
  }
}
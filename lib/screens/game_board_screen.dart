import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../services/live_game_service.dart'; 

class GameBoardScreen extends StatefulWidget {
  final String sessionTicket;
  final String roomId;
  final String myPlayFabId;
  final String myName;
  final int myTrophies;
  final String opponentId;
  final String opponentName;
  final int opponentTrophies;
  final int betAmount;

  const GameBoardScreen({
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
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  LiveGameService? _liveGameService;
  bool _isSimulation = false;

  String _gameState = "initialRoll"; 
  String _currentTurnId = "";
  
  int _myInitialRoll = 0;
  int _opponentInitialRoll = 0;
  bool _isRolling = false;
  String _centerMessage = "לחץ כדי להטיל קוביית פתיחה";

  int _timeLeft = 60;
  Timer? _turnTimer;
  int _myStrikes = 0;
  int _opponentStrikes = 0;
  
  int _die1 = 0;
  int _die2 = 0;
  bool _hasRolledThisTurn = false;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    if (widget.roomId.isEmpty || widget.sessionTicket.isEmpty) {
      _isSimulation = true;
      _currentTurnId = widget.myPlayFabId; 
    } else {
      _liveGameService = LiveGameService(sessionTicket: widget.sessionTicket, roomId: widget.roomId);
      _liveGameService!.gameStateStream.listen(_handleServerUpdate);
      _liveGameService!.startListening();
    }
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    if (!_isSimulation && _gameState == "gameOver") {
      _liveGameService?.closeRoom(); 
    }
    _liveGameService?.dispose();
    super.dispose();
  }

  void _handleServerUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
  }

  void _rollInitialDice() {
    if (_isRolling) return;
    setState(() {
      _isRolling = true;
      _centerMessage = "מטיל קוביות...";
    });

    int rolls = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _myInitialRoll = _random.nextInt(6) + 1;
        _opponentInitialRoll = _random.nextInt(6) + 1;
      });
      rolls++;
      if (rolls > 15) {
        timer.cancel();
        _evaluateInitialRoll();
      }
    });
  }

  void _evaluateInitialRoll() {
    if (_myInitialRoll == _opponentInitialRoll) {
      setState(() {
        _centerMessage = "תיקו! מטילים שוב...";
        _isRolling = false;
      });
      Future.delayed(const Duration(seconds: 2), _rollInitialDice);
    } else {
      bool iWon = _myInitialRoll > _opponentInitialRoll;
      setState(() {
        _centerMessage = iWon ? "ניצחת בהגרלה! אתה מתחיל." : "היריב מתחיל.";
        _currentTurnId = iWon ? widget.myPlayFabId : widget.opponentId;
      });
      
      Future.delayed(const Duration(seconds: 2), () {
         if (mounted) {
           setState(() {
             _gameState = "playing";
             _myInitialRoll = 0;
             _opponentInitialRoll = 0;
             _isRolling = false;
           });
           _startTurnTimer();
         }
      });
    }
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    setState(() {
      _timeLeft = 60;
      _hasRolledThisTurn = false;
      _die1 = 0;
      _die2 = 0;
    });

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() { _timeLeft--; });
      } else {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    setState(() {
      if (_currentTurnId == widget.myPlayFabId) {
        _myStrikes++;
        if (_myStrikes >= 2) {
          _endGame(winnerName: widget.opponentName);
          return;
        }
        _currentTurnId = widget.opponentId; 
      } else {
        _opponentStrikes++;
        if (_opponentStrikes >= 2) {
          _endGame(winnerName: widget.myName);
          return;
        }
        _currentTurnId = widget.myPlayFabId; 
      }
      _startTurnTimer();
    });
  }

  void _rollPlayingDice() {
    setState(() { _isRolling = true; });
    int rolls = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _die1 = _random.nextInt(6) + 1;
        _die2 = _random.nextInt(6) + 1;
      });
      rolls++;
      if (rolls > 15) {
        timer.cancel();
        setState(() {
          _isRolling = false;
          _hasRolledThisTurn = true;
        });
        if (!_isSimulation) {
          _liveGameService?.updateGameState({"die1": "$_die1", "die2": "$_die2"});
        }
      }
    });
  }

  void _endGame({required String winnerName}) {
    setState(() { _gameState = "gameOver"; });
    _turnTimer?.cancel();
    if (!_isSimulation) _liveGameService?.closeRoom();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2328),
        title: const Text("ניצחון טכני", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        content: Text("לשחקן נגמר הזמן פעמיים ברציפות.\nהמנצח הוא: $winnerName!", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text("יציאה לדף הבית", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // --- פופ-אפ אישור יציאה מהמשחק ---
  void _confirmExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2328),
        title: const Text("יציאה מהמשחק", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("האם אתה בטוח שברצונך לצאת?\nהחדר ייסגר והמשחק יסתיים.", textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("ביטול", style: TextStyle(color: Colors.grey, fontSize: 16))
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); 
              if (!_isSimulation) _liveGameService?.closeRoom(); // סוגר חדר
              Navigator.of(context).popUntil((route) => route.isFirst); // חוזר לבית
            }, 
            child: const Text("צא מהמשחק", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl, 
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset('assets/background_dark.png', fit: BoxFit.cover),
                ),

                // כפתור יציאה (X) שיחזיר הביתה
                Positioned(
                  top: height * 0.05,
                  right: width * 0.02,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 35),
                    onPressed: _confirmExitDialog,
                  ),
                ),

                Row(
                  children: [
                    SizedBox(width: width * 0.22, child: _buildMyPanel()),
                    Expanded(child: _buildCenterBoard()),
                    SizedBox(width: width * 0.22, child: _buildOpponentPanel()),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMyPanel() {
    bool isMyTurn = _currentTurnId == widget.myPlayFabId && _gameState == "playing";
    return Container(
      color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey, border: Border.all(color: isMyTurn ? Colors.greenAccent : Colors.white, width: 3), boxShadow: isMyTurn ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 10)] : []),
            child: const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 5),
          Text(widget.myName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 16), const SizedBox(width: 5), Text("${widget.myTrophies}", style: const TextStyle(color: Colors.white))]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.monetization_on, color: Colors.amber, size: 16), const SizedBox(width: 5), Text("${widget.betAmount}", style: const TextStyle(color: Colors.white))]),
          
          const Spacer(),

          if (isMyTurn) ...[
            const Icon(Icons.hourglass_bottom, color: Colors.white, size: 28),
            Text("$_timeLeft", style: TextStyle(color: _timeLeft <= 10 ? Colors.red : Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ] else const SizedBox(height: 60),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close, color: _myStrikes >= 1 ? Colors.red : Colors.grey.withOpacity(0.5), size: 30),
              const SizedBox(width: 5),
              Icon(Icons.close, color: _myStrikes >= 2 ? Colors.red : Colors.grey.withOpacity(0.5), size: 30),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildOpponentPanel() {
    bool isOpponentTurn = _currentTurnId == widget.opponentId && _gameState == "playing";
    return Container(
      color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey, border: Border.all(color: isOpponentTurn ? Colors.redAccent : Colors.white, width: 3), boxShadow: isOpponentTurn ? [const BoxShadow(color: Colors.redAccent, blurRadius: 10)] : []),
            child: const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 5),
          Text(widget.opponentName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 16), const SizedBox(width: 5), Text("${widget.opponentTrophies}", style: const TextStyle(color: Colors.white))]),
          
          const Spacer(),

          if (isOpponentTurn) ...[
            const Icon(Icons.hourglass_bottom, color: Colors.white, size: 28),
            Text("$_timeLeft", style: TextStyle(color: _timeLeft <= 10 ? Colors.red : Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ] else const SizedBox(height: 60),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close, color: _opponentStrikes >= 1 ? Colors.red : Colors.grey.withOpacity(0.5), size: 30),
              const SizedBox(width: 5),
              Icon(Icons.close, color: _opponentStrikes >= 2 ? Colors.red : Colors.grey.withOpacity(0.5), size: 30),
            ],
          ),

          const SizedBox(height: 15),

          if (isOpponentTurn && _hasRolledThisTurn)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_buildDice(_die1, size: 35), const SizedBox(width: 5), _buildDice(_die2, size: 35)],
            ),

          const Spacer(),

          if (_isSimulation && isOpponentTurn)
             ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 5)),
               onPressed: () {
                 setState(() { _die1 = _random.nextInt(6)+1; _die2 = _random.nextInt(6)+1; _hasRolledThisTurn = true; });
                 Future.delayed(const Duration(seconds: 2), () {
                   setState(() { _currentTurnId = widget.myPlayFabId; _startTurnTimer(); });
                 });
               },
               child: const Text("דמה מהלך יריב", style: TextStyle(fontSize: 10, color: Colors.white)),
             ),
        ],
      ),
    );
  }

  Widget _buildCenterBoard() {
    if (_gameState == "initialRoll") {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("הגרלת פתיחה", style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(children: [const Text("אני", style: TextStyle(color: Colors.white, fontSize: 18)), const SizedBox(height: 8), _buildDice(_myInitialRoll)]),
                  const SizedBox(width: 50),
                  Column(children: [const Text("יריב", style: TextStyle(color: Colors.white, fontSize: 18)), const SizedBox(height: 8), _buildDice(_opponentInitialRoll)]),
                ],
              ),
              const SizedBox(height: 20),
              Text(_centerMessage, style: const TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 15),
              if (!_isRolling && _myInitialRoll == 0)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _rollInitialDice,
                  child: const Text("הטל קובייה", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: double.infinity, height: double.infinity, margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 2), color: Colors.brown.withOpacity(0.3)),
          child: const Center(child: Text("כאן ימוקמו\nמשולשי הלוח והכלים", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 30))),
        ),

        if (_currentTurnId == widget.myPlayFabId)
          if (!_hasRolledThisTurn)
             ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
               onPressed: _isRolling ? null : _rollPlayingDice,
               child: _isRolling 
                 ? const CircularProgressIndicator(color: Colors.black)
                 : const Text("זרוק קוביות!", style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
             )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [_buildDice(_die1, size: 60), const SizedBox(width: 15), _buildDice(_die2, size: 60)],
            ),
      ],
    );
  }

  Widget _buildDice(int value, {double size = 50}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: value == 0 ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: value == 0 ? [] : [const BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2))],
      ),
      child: Center(
        child: Text(
          value == 0 ? "?" : "$value", 
          style: TextStyle(color: Colors.black, fontSize: size * 0.6, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }
}
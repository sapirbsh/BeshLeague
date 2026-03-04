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
  List<int> _availableMoves = [];
  bool _hasRolledThisTurn = false;

  final Random _random = Random();

  // --- מנוע המשחק (Backgammon Engine) ---
  List<int> _board = List.filled(24, 0);
  int _myBar = 0; 
  int _oppBar = 0; 
  int _myBorneOff = 0; 
  int _oppBorneOff = 0;
  
  int? _selectedPoint; 
  Set<int> _validDestinations = {}; 

  @override
  void initState() {
    super.initState();
    _initBoard(); 
    
    if (widget.roomId.isEmpty || widget.sessionTicket.isEmpty) {
      _isSimulation = true;
      _currentTurnId = widget.myPlayFabId; 
    } else {
      _liveGameService = LiveGameService(sessionTicket: widget.sessionTicket, roomId: widget.roomId);
      _liveGameService!.gameStateStream.listen(_handleServerUpdate);
      _liveGameService!.startListening();
    }
  }

  void _initBoard() {
    _board = List.filled(24, 0);
    // סידור שש-בש קלאסי
    _board[23] = 2;
    _board[12] = 5;
    _board[7] = 3;
    _board[5] = 5;

    _board[0] = -2;
    _board[11] = -5;
    _board[16] = -3;
    _board[18] = -5;
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
    setState(() { _isRolling = true; _centerMessage = "מטיל קוביות..."; });

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
      setState(() { _centerMessage = "תיקו! מטילים שוב..."; _isRolling = false; });
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
      _availableMoves.clear();
      _selectedPoint = null;
      _validDestinations.clear();
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
        if (_myStrikes >= 2) { _endGame(winnerName: widget.opponentName); return; }
        _currentTurnId = widget.opponentId; 
      } else {
        _opponentStrikes++;
        if (_opponentStrikes >= 2) { _endGame(winnerName: widget.myName); return; }
        _currentTurnId = widget.myPlayFabId; 
      }
      _startTurnTimer();
    });
  }

  void _endTurn() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _currentTurnId = widget.opponentId;
        _startTurnTimer();
      });
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
          if (_die1 == _die2) {
            _availableMoves = [_die1, _die1, _die1, _die1];
          } else {
            _availableMoves = [_die1, _die2];
          }
        });
        
        if (!_hasAnyValidMove()) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("אין מהלכים אפשריים!", textAlign: TextAlign.center)));
          _endTurn();
        }
      }
    });
  }

  bool _canBearOff() {
    if (_myBar > 0) return false;
    for (int i = 6; i < 24; i++) {
      if (_board[i] > 0) return false; 
    }
    return true;
  }

  Set<int> _getValidDestinations(int source) {
    Set<int> valid = {};
    if (_availableMoves.isEmpty) return valid;
    if (_myBar > 0 && source != 24) return valid; 

    bool canBearOff = _canBearOff();

    for (int move in _availableMoves.toSet()) {
      int dest = source - move; 
      if (dest >= 0) {
        if (_board[dest] >= -1) valid.add(dest);
      } else if (canBearOff) {
        if (dest == -1) {
          valid.add(-1); 
        } else {
          bool checkersBehind = false;
          for (int i = source + 1; i <= 5; i++) {
            if (_board[i] > 0) checkersBehind = true;
          }
          if (!checkersBehind) valid.add(-1);
        }
      }
    }
    return valid;
  }

  bool _hasAnyValidMove() {
    if (_myBar > 0) return _getValidDestinations(24).isNotEmpty;
    for (int i = 0; i < 24; i++) {
      if (_board[i] > 0 && _getValidDestinations(i).isNotEmpty) return true;
    }
    return false;
  }

  void _executeMove(int dest) {
    setState(() {
      int source = _selectedPoint!;
      int moveDistance = source - dest;

      if (dest == -1) {
        int exact = _availableMoves.firstWhere((m) => source - m == -1, orElse: () => -1);
        if (exact != -1) {
          _availableMoves.remove(exact);
        } else {
          List<int> largerMoves = _availableMoves.where((m) => m > source + 1).toList();
          largerMoves.sort();
          _availableMoves.remove(largerMoves.first);
        }
        _myBorneOff++;
        _board[source]--;
      } else {
        _availableMoves.remove(moveDistance);
        if (source == 24) _myBar--; else _board[source]--;

        if (_board[dest] == -1) { 
          _board[dest] = 1;
          _oppBar++;
        } else {
          _board[dest]++;
        }
      }

      _selectedPoint = null;
      _validDestinations.clear();

      if (_myBorneOff == 15) {
        _endGame(winnerName: widget.myName);
        return;
      }

      if (_availableMoves.isEmpty || !_hasAnyValidMove()) {
        _endTurn();
      }
    });
  }

  void _handlePointTap(int index) {
    if (_currentTurnId != widget.myPlayFabId) return;

    setState(() {
      if (_selectedPoint == null) {
        if (index == 24 && _myBar > 0) {
          _selectedPoint = 24;
          _validDestinations = _getValidDestinations(24);
        } else if (_myBar == 0 && index >= 0 && _board[index] > 0) {
          _selectedPoint = index;
          _validDestinations = _getValidDestinations(index);
        }
      } else {
        if (_selectedPoint == index) {
          _selectedPoint = null; 
          _validDestinations.clear();
        } else if (_validDestinations.contains(index)) {
          _executeMove(index); 
        } else if (index >= 0 && _board[index] > 0 && _myBar == 0) {
          _selectedPoint = index;
          _validDestinations = _getValidDestinations(index);
        }
      }
    });
  }

  void _endGame({required String winnerName}) {
    setState(() { _gameState = "gameOver"; });
    _turnTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2328),
        title: const Text("המשחק נגמר!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        content: Text("המנצח הוא: $winnerName 🏆", textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 22)),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text("חזור למסך הבית", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _confirmExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2328),
        title: const Text("יציאה מהמשחק", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("האם אתה בטוח שברצונך לצאת?\nהחדר ייסגר והמשחק יסתיים.", textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ביטול", style: TextStyle(color: Colors.grey, fontSize: 16))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); 
              if (!_isSimulation) _liveGameService?.closeRoom(); 
              Navigator.of(context).popUntil((route) => route.isFirst); 
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
                Positioned.fill(child: Image.asset('assets/background_dark.png', fit: BoxFit.cover)),
                // כפתור איקס ליציאה מהמשחק
                Positioned(
                  top: height * 0.05, right: width * 0.02,
                  child: IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 35), onPressed: _confirmExitDialog),
                ),
                Row(
                  children: [
                    SizedBox(width: width * 0.18, child: _buildMyPanel()),
                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: _buildCenterBoard())),
                    SizedBox(width: width * 0.18, child: _buildOpponentPanel()),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- פאנלים בצדדים ---
  Widget _buildMyPanel() {
    bool isMyTurn = _currentTurnId == widget.myPlayFabId && _gameState == "playing";
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isMyTurn ? Colors.greenAccent : Colors.white, width: 3), boxShadow: isMyTurn ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 10)] : []), child: const Icon(Icons.person, color: Colors.white, size: 40)),
          const SizedBox(height: 5),
          Text(widget.myName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (isMyTurn) ...[const Icon(Icons.hourglass_bottom, color: Colors.white, size: 28), Text("$_timeLeft", style: TextStyle(color: _timeLeft <= 10 ? Colors.red : Colors.white, fontSize: 32, fontWeight: FontWeight.bold))] else const SizedBox(height: 60),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.close, color: _myStrikes >= 1 ? Colors.red : Colors.grey.withOpacity(0.5), size: 30), const SizedBox(width: 5), Icon(Icons.close, color: _myStrikes >= 2 ? Colors.red : Colors.grey.withOpacity(0.5), size: 30)]),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildOpponentPanel() {
    bool isOpponentTurn = _currentTurnId == widget.opponentId && _gameState == "playing";
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isOpponentTurn ? Colors.redAccent : Colors.white, width: 3), boxShadow: isOpponentTurn ? [const BoxShadow(color: Colors.redAccent, blurRadius: 10)] : []), child: const Icon(Icons.person, color: Colors.white, size: 40)),
          const SizedBox(height: 5),
          Text(widget.opponentName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (isOpponentTurn) ...[const Icon(Icons.hourglass_bottom, color: Colors.white, size: 28), Text("$_timeLeft", style: TextStyle(color: _timeLeft <= 10 ? Colors.red : Colors.white, fontSize: 32, fontWeight: FontWeight.bold))] else const SizedBox(height: 60),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.close, color: _opponentStrikes >= 1 ? Colors.red : Colors.grey.withOpacity(0.5), size: 30), const SizedBox(width: 5), Icon(Icons.close, color: _opponentStrikes >= 2 ? Colors.red : Colors.grey.withOpacity(0.5), size: 30)]),
          const SizedBox(height: 15),
          if (_isSimulation && isOpponentTurn)
             ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
               onPressed: () => setState(() { _currentTurnId = widget.myPlayFabId; _startTurnTimer(); }),
               child: const Text("דלג תור יריב", style: TextStyle(fontSize: 12, color: Colors.white)),
             ),
          const Spacer(),
        ],
      ),
    );
  }

  // --- לוח השש-בש המעוצב ---
  Widget _buildCenterBoard() {
    if (_gameState == "initialRoll") {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("הגרלת פתיחה", style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Column(children: [const Text("אני", style: TextStyle(color: Colors.white)), const SizedBox(height: 8), _buildDice(_myInitialRoll)]), const SizedBox(width: 50), Column(children: [const Text("יריב", style: TextStyle(color: Colors.white)), const SizedBox(height: 8), _buildDice(_opponentInitialRoll)])]),
              const SizedBox(height: 20), Text(_centerMessage, style: const TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 15), if (!_isRolling && _myInitialRoll == 0) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: _rollInitialDice, child: const Text("הטל קובייה", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr, 
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.5, 
          child: Container(
            padding: const EdgeInsets.all(6), // עובי מסגרת העץ
            decoration: BoxDecoration(
              // טקסטורת עץ למסגרת החיצונית
              gradient: const LinearGradient(
                colors: [Color(0xFF5C3A21), Color(0xFF8B5A2B), Color(0xFF5C3A21)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: const Color(0xFF2E1C11), width: 3), 
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 10))],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDEBCE), // צבע רקע פנימי בהיר (שמנת)
                border: Border.all(color: const Color(0xFF3E2723), width: 2),
              ),
              child: Row(
                children: [
                  // צד שמאל של הלוח
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(12 + i, isTop: true)))),
                        SizedBox(height: 40, child: Center(child: _buildDiceArea())), 
                        Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(11 - i, isTop: false)))),
                      ],
                    ),
                  ),
                  
                  // האמצע (The Bar)
                  GestureDetector(
                    onTap: () => _handlePointTap(24),
                    child: Container(
                      width: 40, // ציר עץ אמיתי באמצע
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A2F1D), Color(0xFF6B4226), Color(0xFF4A2F1D)],
                        ),
                        border: const Border.symmetric(vertical: BorderSide(color: Color(0xFF2E1C11), width: 3)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 5, spreadRadius: 1)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (_oppBar > 0) ...List.generate(_oppBar, (i) => _buildChecker(false)),
                          if (_selectedPoint == 24) Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width: 3))), 
                          if (_myBar > 0) ...List.generate(_myBar, (i) => _buildChecker(true)),
                        ],
                      ),
                    ),
                  ),

                  // צד ימין של הלוח (הבית)
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(18 + i, isTop: true)))),
                        const SizedBox(height: 40), 
                        Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(5 - i, isTop: false)))),
                      ],
                    ),
                  ),

                  // אזור הוצאת כלים (Borne Off)
                  GestureDetector(
                    onTap: () => _handlePointTap(-1),
                    child: Container(
                      width: 55, 
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E2723), 
                        border: const Border(left: BorderSide(color: Color(0xFF2E1C11), width: 4)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, spreadRadius: 1, offset: const Offset(-2, 0))],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_validDestinations.contains(-1)) Container(height: 50, color: Colors.greenAccent.withOpacity(0.5), child: const Center(child: Icon(Icons.check, color: Colors.white))),
                          Expanded(child: Center(child: Text("יצאו: $_myBorneOff", style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center))),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoint(int index, {required bool isTop}) {
    int checkersCount = _board[index].abs();
    bool isMine = _board[index] > 0;
    bool isSelected = _selectedPoint == index;
    bool isTarget = _validDestinations.contains(index);

    // צבעים עשירים למשולשים (שמנת ובורדו עמוק)
    Color triangleColor = (index % 2 == (isTop ? 0 : 1)) 
        ? const Color(0xFFE8DCC4) 
        : const Color(0xFF8B251D); 

    return Expanded(
      child: GestureDetector(
        onTap: () => _handlePointTap(index),
        child: Container(
          decoration: BoxDecoration(
            color: isTarget ? Colors.greenAccent.withOpacity(0.4) : Colors.transparent, 
          ),
          child: CustomPaint(
            painter: TrianglePainter(triangleColor, isTop),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisAlignment: isTop ? MainAxisAlignment.start : MainAxisAlignment.end,
                children: List.generate(checkersCount > 5 ? 5 : checkersCount, (i) {
                  if (i == 4 && checkersCount > 5) return _buildChecker(isMine, isSelected: isSelected && i == 4, extraCount: checkersCount - 4);
                  return _buildChecker(isMine, isSelected: isSelected && i == checkersCount - 1);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // כלים תלת מימדיים עם טבעת
  Widget _buildChecker(bool isMine, {bool isSelected = false, int extraCount = 0}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      width: 30, height: 30, 
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // מראה תלת-ממדי מבריק לפלסטיק של הכלי
        gradient: RadialGradient(
          colors: isMine 
              ? [Colors.white, Colors.grey.shade400] 
              : [const Color(0xFF555555), const Color(0xFF151515)], 
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
        ),
        border: Border.all(
          color: isSelected ? Colors.yellowAccent : (isMine ? Colors.grey.shade500 : Colors.black87), 
          width: isSelected ? 3 : 1.5
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(2, 2)),
          BoxShadow(color: Colors.white.withOpacity(isMine ? 0.9 : 0.1), blurRadius: 1, spreadRadius: -1),
        ],
      ),
      child: Center(
        child: Container(
          // העיגול הפנימי שנמצא בכלים מקצועיים
          width: 16, height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isMine ? Colors.grey.shade300 : Colors.black45, width: 1.5),
          ),
          child: extraCount > 0 
            ? Center(child: Text("+$extraCount", style: TextStyle(color: isMine ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold))) 
            : null,
        ),
      ),
    );
  }

  Widget _buildDiceArea() {
    if (_currentTurnId == widget.myPlayFabId) {
      if (!_hasRolledThisTurn) {
         return ElevatedButton(
           style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal: 20)),
           onPressed: _isRolling ? null : _rollPlayingDice,
           child: _isRolling ? const CircularProgressIndicator(color: Colors.black) : const Text("זרוק", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
         );
      } else {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDice(_die1, size: 30, consumed: !_availableMoves.contains(_die1)), 
            const SizedBox(width: 10), 
            _buildDice(_die2, size: 30, consumed: !_availableMoves.contains(_die2))
          ],
        );
      }
    }
    return const SizedBox(); 
  }

  // קוביות תלת מימד עם צל
  Widget _buildDice(int value, {double size = 50, bool consumed = false}) {
    return Opacity(
      opacity: consumed ? 0.3 : 1.0, 
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          gradient: value == 0 
            ? null 
            : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFD6D6D6)]),
          color: value == 0 ? Colors.grey[800] : null, 
          borderRadius: BorderRadius.circular(8), 
          border: Border.all(color: Colors.black26, width: 1),
          boxShadow: value == 0 ? [] : [const BoxShadow(color: Colors.black54, blurRadius: 5, offset: Offset(2, 3))],
        ),
        child: Center(child: Text(value == 0 ? "?" : "$value", style: TextStyle(color: Colors.black, fontSize: size * 0.6, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  final bool isTop;
  TrianglePainter(this.color, this.isTop);

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    if (isTop) {
      path.moveTo(0, 0); 
      path.lineTo(size.width, 0); 
      path.lineTo(size.width / 2, size.height * 0.85); 
    } else {
      path.moveTo(0, size.height); 
      path.lineTo(size.width, size.height); 
      path.lineTo(size.width / 2, size.height * 0.15); 
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}
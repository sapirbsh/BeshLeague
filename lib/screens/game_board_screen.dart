import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../services/live_game_service.dart';
import '../services/bot_service.dart';

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
  final BotSkill? botSkill;

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
    this.botSkill,
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  LiveGameService? _liveGameService;
  bool _isSimulation = false;
  bool get _isBotMatch => widget.botSkill != null;

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
  final List<Map<String, dynamic>> _moveHistory = [];

  // Win screen
  bool _showWinScreen = false;
  bool _winnerIsMe = false;
  int _xpEarned = 0;
  bool _isBoostGame = false;
  int _levelBefore = 1;
  int _levelAfter = 1;
  int _totalXpAfter = 0;

  // XP helpers (exponential: 100 * level^1.5)
  static int _xpNeededForLevel(int level) => (100 * pow(level, 1.5)).round();
  static int _levelFromTotalXP(int totalXp) {
    int level = 1;
    int acc = 0;
    while (true) {
      final needed = _xpNeededForLevel(level);
      if (acc + needed > totalXp) break;
      acc += needed;
      level++;
    }
    return level;
  }
  static int _xpInCurrentLevel(int totalXp, int level) {
    int acc = 0;
    for (int l = 1; l < level; l++) acc += _xpNeededForLevel(l);
    return totalXp - acc;
  }

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
    // ניכוי 50 מטבעות כשהמשחק מתחיל בפועל
    _deductBetCoins();
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
           if (_isBotMatch && _currentTurnId == widget.opponentId) {
             _scheduleBotTurn();
           }
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

    _moveHistory.clear();

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
      final nextTurn = (_currentTurnId == widget.myPlayFabId) ? widget.opponentId : widget.myPlayFabId;
      setState(() { _currentTurnId = nextTurn; });
      _startTurnTimer();
      if (_isBotMatch && nextTurn == widget.opponentId) {
        _scheduleBotTurn();
      }
    });
  }

  // --- Bot auto-play logic ---

  void _scheduleBotTurn() {
    final delay = BotService.getThinkDelay(widget.botSkill!);
    Future.delayed(delay, () {
      if (!mounted || _currentTurnId != widget.opponentId || _gameState != "playing") return;
      _rollPlayingDiceForBot();
    });
  }

  void _rollPlayingDiceForBot() {
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
          _availableMoves = (_die1 == _die2) ? [_die1, _die1, _die1, _die1] : [_die1, _die2];
        });
        _executeBotMovesSequentially();
      }
    });
  }

  void _executeBotMovesSequentially() {
    if (!mounted || _gameState != "playing") return;
    if (_availableMoves.isEmpty) { _endTurn(); return; }

    final move = BotService.selectBotMove(_board, List.from(_availableMoves), _oppBar, widget.botSkill!);
    if (move == null) { _endTurn(); return; }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _gameState != "playing") return;
      _executeBotMove(move.source, move.dest);
      // Only continue if game is still in progress
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_gameState == "playing") _executeBotMovesSequentially();
      });
    });
  }

  void _executeBotMove(int source, int dest) {
    bool gameWon = false;

    setState(() {
      if (dest == 24) {
        // Bear off: prefer exact die, else smallest overshooting die
        final neededDie = 24 - source;
        int dieUsed = -1;
        if (_availableMoves.contains(neededDie)) {
          dieUsed = neededDie;
        } else {
          final overshooting = _availableMoves.where((m) => m > neededDie).toList()..sort();
          if (overshooting.isNotEmpty) dieUsed = overshooting.first;
        }
        if (dieUsed != -1) _availableMoves.remove(dieUsed);
        _oppBorneOff++;
        _board[source]++; // remove one bot piece (less negative, toward 0)
        if (_oppBorneOff == 15) gameWon = true;
      } else {
        if (source == 25) {
          // Bar entry: die value = dest + 1 (since bot enters at index mv-1, so mv = dest+1)
          _availableMoves.remove(dest + 1);
          _oppBar--;
        } else {
          _availableMoves.remove(dest - source);
          _board[source]++; // remove one bot piece
        }

        if (_board[dest] == 1) {
          // Hit a human blot
          _board[dest] = -1;
          _myBar++;
        } else {
          _board[dest]--; // add bot piece
        }
      }
    });

    if (gameWon) {
      _endGame(winnerName: widget.opponentName);
    }
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
        } else {
          _checkAndAutoMove();
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

  List<MapEntry<int, int>> _getAllValidMoves() {
    List<MapEntry<int, int>> all = [];
    if (_myBar > 0) {
      for (int dest in _getValidDestinations(24)) {
        all.add(MapEntry(24, dest));
      }
    } else {
      for (int i = 0; i < 24; i++) {
        if (_board[i] > 0) {
          for (int dest in _getValidDestinations(i)) {
            all.add(MapEntry(i, dest));
          }
        }
      }
    }
    return all;
  }

  void _checkAndAutoMove() {
    if (!mounted || _currentTurnId != widget.myPlayFabId || _availableMoves.isEmpty || _gameState != "playing") return;
    final moves = _getAllValidMoves();
    if (moves.isEmpty) return;
    final unique = moves.map((e) => '${e.key}:${e.value}').toSet();
    if (unique.length == 1) {
      final move = moves.first;
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || _currentTurnId != widget.myPlayFabId || _availableMoves.isEmpty || _gameState != "playing") return;
        setState(() {
          _selectedPoint = move.key;
          _validDestinations = {move.value};
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _currentTurnId != widget.myPlayFabId || _availableMoves.isEmpty || _gameState != "playing") return;
          _executeMove(move.value);
          Future.delayed(const Duration(milliseconds: 400), _checkAndAutoMove);
        });
      });
    }
  }

  void _undoLastMove() {
    if (_moveHistory.isEmpty) return;
    final snap = _moveHistory.removeLast();
    setState(() {
      _board = List<int>.from(snap['board']);
      _myBar = snap['myBar'];
      _oppBar = snap['oppBar'];
      _myBorneOff = snap['myBorneOff'];
      _availableMoves = List<int>.from(snap['availableMoves']);
      _selectedPoint = null;
      _validDestinations.clear();
    });
  }

  void _executeMove(int dest) {
    _moveHistory.add({
      'board': List<int>.from(_board),
      'myBar': _myBar,
      'oppBar': _oppBar,
      'myBorneOff': _myBorneOff,
      'availableMoves': List<int>.from(_availableMoves),
    });

    bool gameWon = false;
    bool turnEnded = false;

    setState(() {
      int source = _selectedPoint!;
      int moveDistance = source - dest;

      if (dest == -1) {
        // Bear off: prefer exact die, else smallest overshooting die
        final neededDie = source + 1;
        int dieUsed = -1;
        if (_availableMoves.contains(neededDie)) {
          dieUsed = neededDie;
        } else {
          final overshooting = _availableMoves.where((m) => m > neededDie).toList()..sort();
          if (overshooting.isNotEmpty) dieUsed = overshooting.first;
        }
        if (dieUsed != -1) _availableMoves.remove(dieUsed);
        _myBorneOff++;
        _board[source]--;
      } else {
        _availableMoves.remove(moveDistance);
        if (source == 24) {
          _myBar--;
        } else {
          _board[source]--;
        }

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
        gameWon = true;
      } else if (_availableMoves.isEmpty || !_hasAnyValidMove()) {
        turnEnded = true;
      }
    });

    if (gameWon) {
      _endGame(winnerName: widget.myName);
    } else if (turnEnded) {
      _endTurn();
    }
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

  Future<void> _deductBetCoins() async {
    if (widget.sessionTicket.isEmpty) return;
    try {
      await http.post(
        Uri.parse('https://1A15A2.playfabapi.com/Client/SubtractUserVirtualCurrency'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"VirtualCurrency": "CO", "Amount": widget.betAmount}),
      );
    } catch (_) {}
  }

  void _endGame({required String winnerName}) {
    _turnTimer?.cancel();
    final iWon = winnerName == widget.myName;
    setState(() {
      _gameState = "gameOver";
      _winnerIsMe = iWon;
    });
    _awardXPAndCoins(iWon: iWon);
  }

  Future<void> _awardXPAndCoins({required bool iWon}) async {
    if (widget.sessionTicket.isEmpty) {
      if (mounted) setState(() { _showWinScreen = true; });
      return;
    }
    try {
      final res = await http.post(
        Uri.parse('https://1A15A2.playfabapi.com/Client/GetUserData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"Keys": ["TotalXP", "DailyGamesPlayed", "LastGameDate"]}),
      );
      int totalXp = 0;
      int dailyGames = 0;
      String lastGameDate = '';
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data']?['Data'];
        totalXp = int.tryParse(data?['TotalXP']?['Value'] ?? '0') ?? 0;
        dailyGames = int.tryParse(data?['DailyGamesPlayed']?['Value'] ?? '0') ?? 0;
        lastGameDate = data?['LastGameDate']?['Value'] ?? '';
      }
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      if (lastGameDate != today) dailyGames = 0;
      final isBoost = dailyGames < 5;
      final xpEarned = isBoost ? 50 : 25;
      final newTotalXP = totalXp + xpEarned;
      final newDailyGames = isBoost ? dailyGames + 1 : dailyGames;
      final levelBefore = _levelFromTotalXP(totalXp);
      final levelAfter = _levelFromTotalXP(newTotalXP);

      await http.post(
        Uri.parse('https://1A15A2.playfabapi.com/Client/UpdateUserData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"Data": {
          "TotalXP": newTotalXP.toString(),
          "DailyGamesPlayed": newDailyGames.toString(),
          "LastGameDate": today,
        }}),
      );
      if (iWon) {
        await http.post(
          Uri.parse('https://1A15A2.playfabapi.com/Client/AddUserVirtualCurrency'),
          headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
          body: json.encode({"VirtualCurrency": "CO", "Amount": widget.betAmount * 2}),
        );
      }
      if (mounted) {
        setState(() {
          _xpEarned = xpEarned;
          _isBoostGame = isBoost;
          _levelBefore = levelBefore;
          _levelAfter = levelAfter;
          _totalXpAfter = newTotalXP;
          _showWinScreen = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _showWinScreen = true; });
    }
  }

  void _confirmExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2328),
        title: const Text("לפרוש מהמשחק?", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Text("אם תפרוש:", textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text("יירדו לך 50 מטבעות", style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
              SizedBox(width: 6),
              Icon(Icons.monetization_on, color: Colors.redAccent, size: 18),
            ]),
            SizedBox(height: 4),
            Text("היריב יזכה בניצחון טכני", textAlign: TextAlign.right, style: TextStyle(color: Colors.orange, fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("המשך במשחק", style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.sessionTicket.isNotEmpty) {
                try {
                  await http.post(
                    Uri.parse('https://1A15A2.playfabapi.com/Client/SubtractUserVirtualCurrency'),
                    headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
                    body: json.encode({"VirtualCurrency": "CO", "Amount": 50}),
                  );
                } catch (_) {}
              }
              if (!_isSimulation) _liveGameService?.closeRoom();
              if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("פרוש", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
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
                Row(
                  children: [
                    SizedBox(width: width * 0.18, child: _buildMyPanel()),
                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: _buildCenterBoard())),
                    SizedBox(width: width * 0.18, child: _buildOpponentPanel()),
                  ],
                ),

                // מסך ניצחון
                if (_showWinScreen) _buildWinScreen(width, height),

                // כפתור ביטול צעד אחרון
                if (_gameState == "playing" && _currentTurnId == widget.myPlayFabId && _moveHistory.isNotEmpty)
                  Positioned(
                    bottom: height * 0.04,
                    left: width * 0.18 + 8,
                    child: GestureDetector(
                      onTap: _undoLastMove,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 1.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo, color: Colors.amber, size: 18),
                            SizedBox(width: 5),
                            Text("בטל צעד", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
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
          Text(widget.myName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (isMyTurn)
            GestureDetector(
              onTap: _confirmExitDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFB73E3E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black54, width: 1)),
                child: const Text("לפרוש", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
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
              child: LayoutBuilder(
                builder: (ctx, innerC) {
                  const double barW = 40, bornOffW = 55;
                  final double pointAreaW = innerC.maxWidth - barW - bornOffW;
                  final double pointW = pointAreaW / 12;
                  final double colH = (innerC.maxHeight - 42) / 2;
                  final double cs = min(pointW * 0.86, colH / 5.4).clamp(10.0, 36.0);

                  return Row(
                    children: [
                      // צד שמאל של הלוח
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(12 + i, isTop: true, cs: cs)))),
                            SizedBox(height: 42, child: Center(child: _buildDiceArea(cs: cs))),
                            Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(11 - i, isTop: false, cs: cs)))),
                          ],
                        ),
                      ),

                      // האמצע (The Bar)
                      GestureDetector(
                        onTap: () => _handlePointTap(24),
                        child: Container(
                          width: barW,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4A2F1D), Color(0xFF6B4226), Color(0xFF4A2F1D)]),
                            border: const Border.symmetric(vertical: BorderSide(color: Color(0xFF2E1C11), width: 3)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 5, spreadRadius: 1)],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (_oppBar > 0) ...List.generate(_oppBar, (i) => _buildChecker(false, size: cs)),
                              if (_selectedPoint == 24) Container(width: cs, height: cs, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width: 3))),
                              if (_myBar > 0) ...List.generate(_myBar, (i) => _buildChecker(true, size: cs)),
                            ],
                          ),
                        ),
                      ),

                      // צד ימין של הלוח (הבית)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(18 + i, isTop: true, cs: cs)))),
                            const SizedBox(height: 42),
                            Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(5 - i, isTop: false, cs: cs)))),
                          ],
                        ),
                      ),

                      // אזור הוצאת כלים (Borne Off)
                      GestureDetector(
                        onTap: () => _handlePointTap(-1),
                        child: Container(
                          width: bornOffW,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3E2723),
                            border: const Border(left: BorderSide(color: Color(0xFF2E1C11), width: 4)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, spreadRadius: 1, offset: const Offset(-2, 0))],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_validDestinations.contains(-1))
                                Container(height: 44, color: Colors.greenAccent.withOpacity(0.5), child: const Center(child: Icon(Icons.check, color: Colors.white, size: 20))),
                              Expanded(child: Center(child: Text("יצאו\n$_myBorneOff", style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.center))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoint(int index, {required bool isTop, required double cs}) {
    int checkersCount = _board[index].abs();
    bool isMine = _board[index] > 0;
    bool isSelected = _selectedPoint == index;
    bool isTarget = _validDestinations.contains(index);

    Color triangleColor = (index % 2 == (isTop ? 0 : 1))
        ? const Color(0xFFE8DCC4)
        : const Color(0xFF8B251D);

    return Expanded(
      child: GestureDetector(
        onTap: () => _handlePointTap(index),
        child: Container(
          decoration: BoxDecoration(
            color: isTarget ? Colors.green.withOpacity(0.35) : Colors.transparent,
            border: isTarget ? Border.all(color: Colors.greenAccent, width: 1.5) : null,
          ),
          child: CustomPaint(
            painter: TrianglePainter(triangleColor, isTop),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Column(
                mainAxisAlignment: isTop ? MainAxisAlignment.start : MainAxisAlignment.end,
                children: List.generate(checkersCount > 5 ? 5 : checkersCount, (i) {
                  if (i == 4 && checkersCount > 5) return _buildChecker(isMine, isSelected: isSelected && i == 4, extraCount: checkersCount - 4, size: cs);
                  return _buildChecker(isMine, isSelected: isSelected && i == checkersCount - 1, size: cs);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChecker(bool isMine, {bool isSelected = false, int extraCount = 0, double size = 30}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: size * 0.06),
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isMine
              ? [Colors.white, Colors.grey.shade300]
              : [const Color(0xFF666666), const Color(0xFF111111)],
          center: const Alignment(-0.3, -0.3),
          radius: 0.85,
        ),
        border: Border.all(
          color: isSelected ? Colors.yellow : (isMine ? Colors.grey.shade400 : Colors.black87),
          width: isSelected ? 3 : 1.5,
        ),
        boxShadow: [
          if (isSelected) ...[
            const BoxShadow(color: Colors.yellow, blurRadius: 10, spreadRadius: 3),
            const BoxShadow(color: Colors.orange, blurRadius: 5, spreadRadius: 1),
          ],
          BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 3, offset: const Offset(1, 2)),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.52, height: size * 0.52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isMine ? Colors.grey.shade300 : Colors.black38, width: 1.2),
          ),
          child: extraCount > 0
              ? Center(child: Text("+$extraCount", style: TextStyle(color: isMine ? Colors.black : Colors.white, fontSize: size * 0.3, fontWeight: FontWeight.bold)))
              : null,
        ),
      ),
    );
  }

  Widget _buildDiceArea({double cs = 30}) {
    final double diceSize = (cs * 1.15).clamp(24.0, 40.0);
    if (_currentTurnId == widget.myPlayFabId) {
      if (!_hasRolledThisTurn) {
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isRolling ? null : _rollPlayingDice,
          child: _isRolling
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.casino, color: Colors.black, size: 18),
                  SizedBox(width: 5),
                  Text("זרוק", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
        );
      } else {
        if (_die1 == _die2 && _hasRolledThisTurn) {
          final int remaining = _availableMoves.where((m) => m == _die1).length;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDice(_die1, size: diceSize, consumed: remaining <= 2),
              const SizedBox(width: 8),
              _buildDice(_die2, size: diceSize, consumed: remaining == 0),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDice(_die1, size: diceSize, consumed: !_availableMoves.contains(_die1)),
            const SizedBox(width: 8),
            _buildDice(_die2, size: diceSize, consumed: !_availableMoves.contains(_die2)),
          ],
        );
      }
    }
    if (_isRolling) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDice(_die1, size: diceSize),
          const SizedBox(width: 8),
          _buildDice(_die2, size: diceSize),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildDicePips(int value, double size) {
    final double r = size * 0.09;
    final double L = size * 0.28, C = size * 0.5, R = size * 0.72;
    final double T = size * 0.28, M = size * 0.5, B = size * 0.72;
    final List<List<double>> pos;
    switch (value) {
      case 1: pos = [[C, M]]; break;
      case 2: pos = [[R, T], [L, B]]; break;
      case 3: pos = [[R, T], [C, M], [L, B]]; break;
      case 4: pos = [[L, T], [R, T], [L, B], [R, B]]; break;
      case 5: pos = [[L, T], [R, T], [C, M], [L, B], [R, B]]; break;
      case 6: pos = [[L, T], [R, T], [L, M], [R, M], [L, B], [R, B]]; break;
      default: pos = [];
    }
    return SizedBox(
      width: size, height: size,
      child: Stack(
        children: pos.map((p) => Positioned(
          left: p[0] - r, top: p[1] - r,
          child: Container(width: r * 2, height: r * 2, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A1A1A))),
        )).toList(),
      ),
    );
  }

  Widget _buildDice(int value, {double size = 50, bool consumed = false}) {
    return Opacity(
      opacity: consumed ? 0.3 : 1.0,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: value == 0
                ? [Colors.grey.shade700, Colors.grey.shade900]
                : [const Color(0xFFFAFAFA), const Color(0xFFDDDDDD)],
          ),
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(color: Colors.black45, width: 1.5),
          boxShadow: value == 0 ? [] : [
            const BoxShadow(color: Colors.black54, blurRadius: 5, offset: Offset(2, 3)),
            BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 2, offset: const Offset(-1, -1)),
          ],
        ),
        child: value == 0
            ? Center(child: Icon(Icons.casino_outlined, color: Colors.white54, size: size * 0.55))
            : _buildDicePips(value, size),
      ),
    );
  }

  Widget _buildWinScreen(double width, double height) {
    final coinsAwarded = _winnerIsMe ? widget.betAmount * 2 : 0;
    final winnerLabel = _winnerIsMe ? widget.myName : widget.opponentName;
    final didLevelUp = _levelAfter > _levelBefore;
    final xpNeeded = _xpNeededForLevel(_levelAfter);
    final xpInLevel = _xpInCurrentLevel(_totalXpAfter, _levelAfter);
    final progressFraction = xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 0.0;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: width * 0.65,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A192F), Color(0xFF1A3A5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.amber, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 5)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _winnerIsMe ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                    color: _winnerIsMe ? Colors.amber : Colors.grey,
                    size: 68,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _winnerIsMe ? "ניצחת!" : "הפסדת",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: _winnerIsMe ? Colors.amber : Colors.white60,
                    ),
                  ),
                  Text(winnerLabel, style: const TextStyle(fontSize: 18, color: Colors.white70)),
                  const SizedBox(height: 20),

                  // Coins (winner only)
                  if (_winnerIsMe)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                          const SizedBox(width: 8),
                          Text("+$coinsAwarded מטבעות", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                        ],
                      ),
                    ),

                  // XP earned (always shown)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.lightBlueAccent, size: 22),
                            const SizedBox(width: 8),
                            Text("+$_xpEarned XP", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                            if (_isBoostGame) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                                child: const Text("x2 בונוס!", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressFraction,
                            backgroundColor: Colors.grey[700],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("רמה $_levelAfter  •  $xpInLevel / $xpNeeded XP", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ),

                  // Level-up banner
                  if (didLevelUp) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF6F00)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          Text("עלית לרמה $_levelAfter!", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _winnerIsMe ? Colors.amber : Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: Text(
                      "חזור למסך הבית",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _winnerIsMe ? Colors.black : Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
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

class _GameBoardScreenState extends State<GameBoardScreen>
    with TickerProviderStateMixin {
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
  String? _floatingMessage;

  int? _highlightFrom;
  int? _highlightTo;

  final Random _random = Random();

  // --- backgammon board engine ---
  List<int> _board = List.filled(24, 0);
  int _myBar = 0;
  int _oppBar = 0;
  int _myBorneOff = 0;
  int _oppBorneOff = 0;

  int? _selectedPoint;
  Set<int> _validDestinations = {};
  final List<Map<String, dynamic>> _moveHistory = [];

  // --- action guard ---
  bool _isActionLocked = false;
  int? _hitFlashBar;

  // --- rage quit ---
  bool _isRageQuitting = false;

  // --- opponent dialog ---
  bool _showOpponentDialog = false;

  // --- game timing ---
  late DateTime _gameStartTime;
  Duration _gameDuration = Duration.zero;

  // --- animation controllers ---
  late AnimationController _diceController;
  late AnimationController _coinFlyController;
  late Animation<double> _coinFlyAnim;
  late Animation<double> _diceShakeX;
  late Animation<double> _diceRotation;

  // rage-quit table-flip animation
  late AnimationController _rageController;
  late Animation<double> _rageShakeAnim;   // translateX shake
  late Animation<double> _rageFlipAnim;    // rotateX flip
  late Animation<double> _rageScaleAnim;   // scale out

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  // --- Win screen state ---
  bool _showWinScreen = false;
  bool _winnerIsMe = false;
  int _xpEarned = 0;
  bool _isBoostGame = false;
  int _levelBefore = 1;
  int _levelAfter = 1;
  int _totalXpAfter = 0;
  int _winStreak = 0;
  int _bestWinStreak = 0;

  // XP helpers
  static int _xpNeededForLevel(int level) => (100 * pow(level, 1.5)).round();
  static int _levelFromTotalXP(int totalXp) {
    int level = 1, acc = 0;
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
    _gameStartTime = DateTime.now();

    // dice shake
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 85),
    );
    _diceShakeX = Tween<double>(begin: -6.0, end: 6.0).animate(_diceController);
    _diceRotation = Tween<double>(begin: -0.18, end: 0.18).animate(_diceController);

    // rage-quit table flip (700ms total: 280ms shake + 420ms flip out)
    _rageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _rageShakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 18.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 18.0, end: -18.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: -18.0, end: 18.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 18.0, end: -18.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: -18.0, end: 0.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 60),
    ]).animate(_rageController);
    _rageFlipAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -pi * 1.05), weight: 60),
    ]).animate(_rageController);
    _rageScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.05), weight: 60),
    ]).animate(_rageController);

    // coin fly (win celebration)
    _coinFlyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _coinFlyAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _coinFlyController, curve: Curves.easeOut),
    );

    // selected-checker pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.88, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initBoard();

    if (widget.roomId.isEmpty || widget.sessionTicket.isEmpty) {
      _isSimulation = true;
      _currentTurnId = widget.myPlayFabId;
    } else {
      _liveGameService = LiveGameService(
          sessionTicket: widget.sessionTicket, roomId: widget.roomId);
      _liveGameService!.gameStateStream.listen(_handleServerUpdate);
      _liveGameService!.startListening();
    }
    _deductBetCoins();
  }

  void _initBoard() {
    _board = List.filled(24, 0);
    _board[23] = 2;  _board[12] = 5;  _board[7] = 3;  _board[5] = 5;
    _board[0] = -2;  _board[11] = -5; _board[16] = -3; _board[18] = -5;
  }

  @override
  void dispose() {
    _diceController.dispose();
    _rageController.dispose();
    _pulseController.dispose();
    _coinFlyController.dispose();
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

  // ─── rage-quit (flip board = quit) ───────────────────────────────────────
  void _showFlipBoardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2328),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text("להפוך את הלוח?", textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            SizedBox(width: 8),
            Text("😤", style: TextStyle(fontSize: 22)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Text("אם תפרוש:", textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text("תפסיד 50 מטבעות נוספים",
                  style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
              SizedBox(width: 6),
              Icon(Icons.monetization_on, color: Colors.redAccent, size: 18),
            ]),
            SizedBox(height: 4),
            Text("היריב יזכה בניצחון טכני",
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.orange, fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("המשך במשחק",
                style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeRageQuit();
            },
            child: const Text("הפוך!",
                style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRageQuit() async {
    if (_isRageQuitting) return;
    setState(() { _isRageQuitting = true; _isActionLocked = true; });

    // deduct 50 coin penalty (fire & forget)
    _deductRageQuitPenalty();

    // play the table-flip animation
    await _rageController.forward();

    if (!mounted) return;
    if (!_isSimulation) _liveGameService?.closeRoom();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deductRageQuitPenalty() async {
    if (widget.sessionTicket.isEmpty) return;
    try {
      await http.post(
        Uri.parse('https://1A15A2.playfabapi.com/Client/SubtractUserVirtualCurrency'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"VirtualCurrency": "CO", "Amount": 50}),
      );
    } catch (_) {}
  }

  // ─── initial roll ─────────────────────────────────────────────────────────
  void _rollInitialDice() {
    if (_isRolling || _isActionLocked) return;
    // No dice shake on initial roll — just rapid number cycling
    setState(() { _isRolling = true; _isActionLocked = true; _centerMessage = "מטיל קוביות..."; });
    int rolls = 0;
    Timer.periodic(const Duration(milliseconds: 85), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _myInitialRoll = _random.nextInt(6) + 1;
        _opponentInitialRoll = _random.nextInt(6) + 1;
      });
      rolls++;
      if (rolls >= 18) {
        timer.cancel();
        setState(() { _isActionLocked = false; });
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
          _gameStartTime = DateTime.now(); // start clock when game actually begins
          setState(() { _gameState = "playing"; _isRolling = false; });
          _startTurnTimer();
          if (_isBotMatch && _currentTurnId == widget.opponentId) _scheduleBotTurn();
        }
      });
    }
  }

  // ─── turn timer ───────────────────────────────────────────────────────────
  void _startTurnTimer() {
    _turnTimer?.cancel();
    setState(() {
      _timeLeft = 60;
      _hasRolledThisTurn = false;
      _availableMoves.clear();
      _selectedPoint = null;
      _validDestinations.clear();
      _highlightFrom = null;
      _highlightTo = null;
      _isActionLocked = false;
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
    bool becameBotTurn = false;
    bool becameMyTurn = false;
    setState(() {
      if (_currentTurnId == widget.myPlayFabId) {
        _myStrikes++;
        if (_myStrikes >= 2) { _endGame(winnerName: widget.opponentName); return; }
        _currentTurnId = widget.opponentId;
        becameBotTurn = _isBotMatch;
      } else {
        _opponentStrikes++;
        if (_opponentStrikes >= 2) { _endGame(winnerName: widget.myName); return; }
        _currentTurnId = widget.myPlayFabId;
        becameMyTurn = true;
      }
      _startTurnTimer();
    });
    if (becameMyTurn) {
      HapticFeedback.mediumImpact();
      if (_showOpponentDialog) setState(() { _showOpponentDialog = false; });
    }
    if (becameBotTurn) _scheduleBotTurn();
  }

  void _endTurn() {
    if (_isActionLocked) return;
    setState(() { _isActionLocked = true; _floatingMessage = null; });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final nextTurn = (_currentTurnId == widget.myPlayFabId) ? widget.opponentId : widget.myPlayFabId;
      if (nextTurn == widget.myPlayFabId) HapticFeedback.mediumImpact();
      setState(() { _currentTurnId = nextTurn; _isActionLocked = false; });
      if (_showOpponentDialog && nextTurn == widget.myPlayFabId) {
        setState(() { _showOpponentDialog = false; });
      }
      _startTurnTimer();
      if (_isBotMatch && nextTurn == widget.opponentId) _scheduleBotTurn();
    });
  }

  void _showFloatingMessage(String msg) {
    setState(() { _floatingMessage = msg; });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() { _floatingMessage = null; });
    });
  }

  // ─── bot auto-play ────────────────────────────────────────────────────────
  void _scheduleBotTurn() {
    final delay = BotService.getThinkDelay(widget.botSkill!);
    Future.delayed(delay, () {
      if (!mounted || _currentTurnId != widget.opponentId || _gameState != "playing") return;
      _rollPlayingDiceForBot();
    });
  }

  void _rollPlayingDiceForBot() {
    _diceController.repeat(reverse: true);
    setState(() { _isRolling = true; });
    int rolls = 0;
    Timer.periodic(const Duration(milliseconds: 85), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() { _die1 = _random.nextInt(6) + 1; _die2 = _random.nextInt(6) + 1; });
      rolls++;
      if (rolls >= 18) {
        timer.cancel();
        _diceController.stop(); _diceController.reset();
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
      Future.delayed(const Duration(milliseconds: 350), () {
        if (_gameState == "playing") _executeBotMovesSequentially();
      });
    });
  }

  void _executeBotMove(int source, int dest) {
    bool gameWon = false;
    bool hitBlot = false;
    setState(() {
      if (dest == 24) {
        final neededDie = 24 - source;
        int dieUsed = -1;
        if (_availableMoves.contains(neededDie)) {
          dieUsed = neededDie;
        } else {
          final os = _availableMoves.where((m) => m > neededDie).toList()..sort();
          if (os.isNotEmpty) dieUsed = os.first;
        }
        if (dieUsed != -1) _availableMoves.remove(dieUsed);
        _oppBorneOff++;
        _board[source]++;
        if (_oppBorneOff == 15) gameWon = true;
      } else {
        if (source == 25) {
          _availableMoves.remove(dest + 1);
          _oppBar--;
        } else {
          _availableMoves.remove(dest - source);
          _board[source]++;
        }
        if (_board[dest] == 1) {
          _board[dest] = -1;
          _myBar++;
          hitBlot = true;
        } else {
          _board[dest]--;
        }
      }
      _highlightFrom = (source == 25) ? null : source;
      _highlightTo = (dest == 24) ? null : dest;
    });

    if (hitBlot) {
      setState(() => _hitFlashBar = 1);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _hitFlashBar = null);
      });
    }
    if (gameWon) {
      _endGame(winnerName: widget.opponentName);
    } else {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() { _highlightFrom = null; _highlightTo = null; });
      });
    }
  }

  // ─── player dice roll ─────────────────────────────────────────────────────
  void _rollPlayingDice() {
    if (_hasRolledThisTurn || _isRolling || _isActionLocked) return;
    _diceController.repeat(reverse: true);
    setState(() { _isRolling = true; _isActionLocked = true; });
    int rolls = 0;
    Timer.periodic(const Duration(milliseconds: 85), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() { _die1 = _random.nextInt(6) + 1; _die2 = _random.nextInt(6) + 1; });
      rolls++;
      if (rolls >= 18) {
        timer.cancel();
        _diceController.stop(); _diceController.reset();
        setState(() {
          _isRolling = false;
          _isActionLocked = false;
          _hasRolledThisTurn = true;
          _availableMoves = (_die1 == _die2) ? [_die1, _die1, _die1, _die1] : [_die1, _die2];
        });
        if (!_hasAnyValidMove()) {
          _showFloatingMessage("אין מהלכים אפשריים!");
        } else {
          _checkAndAutoMove();
        }
      }
    });
  }

  // ─── game logic ───────────────────────────────────────────────────────────
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
      for (int dest in _getValidDestinations(24)) all.add(MapEntry(24, dest));
    } else {
      for (int i = 0; i < 24; i++) {
        if (_board[i] > 0) {
          for (int dest in _getValidDestinations(i)) all.add(MapEntry(i, dest));
        }
      }
    }
    return all;
  }

  void _checkAndAutoMove() {
    if (!mounted || _currentTurnId != widget.myPlayFabId || _availableMoves.isEmpty ||
        _gameState != "playing" || _isActionLocked) return;
    final moves = _getAllValidMoves();
    if (moves.isEmpty) return;
    final unique = moves.map((e) => '${e.key}:${e.value}').toSet();
    if (unique.length == 1) {
      final move = moves.first;
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || _currentTurnId != widget.myPlayFabId || _availableMoves.isEmpty ||
            _gameState != "playing" || _isActionLocked) return;
        setState(() { _selectedPoint = move.key; _validDestinations = {move.value}; });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _currentTurnId != widget.myPlayFabId || _availableMoves.isEmpty ||
              _gameState != "playing" || _isActionLocked) return;
          _executeMove(move.value);
          Future.delayed(const Duration(milliseconds: 400), _checkAndAutoMove);
        });
      });
    }
  }

  void _undoLastMove() {
    if (_moveHistory.isEmpty || _isActionLocked || _isRolling) return;
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
      'myBar': _myBar, 'oppBar': _oppBar,
      'myBorneOff': _myBorneOff,
      'availableMoves': List<int>.from(_availableMoves),
    });
    bool gameWon = false;
    bool hitBlot = false;
    setState(() {
      int source = _selectedPoint!;
      int moveDistance = source - dest;
      if (dest == -1) {
        final neededDie = source + 1;
        int dieUsed = -1;
        if (_availableMoves.contains(neededDie)) {
          dieUsed = neededDie;
        } else {
          final os = _availableMoves.where((m) => m > neededDie).toList()..sort();
          if (os.isNotEmpty) dieUsed = os.first;
        }
        if (dieUsed != -1) _availableMoves.remove(dieUsed);
        _myBorneOff++;
        _board[source]--;
      } else {
        _availableMoves.remove(moveDistance);
        if (source == 24) { _myBar--; } else { _board[source]--; }
        if (_board[dest] == -1) {
          _board[dest] = 1;
          _oppBar++;
          hitBlot = true;
        } else {
          _board[dest]++;
        }
      }
      _selectedPoint = null;
      _validDestinations.clear();
      _highlightFrom = (source == 24) ? null : source;
      _highlightTo = (dest == -1) ? null : dest;
      if (_myBorneOff == 15) gameWon = true;
    });

    if (hitBlot) {
      setState(() => _hitFlashBar = -1);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _hitFlashBar = null);
      });
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() { _highlightFrom = null; _highlightTo = null; });
    });
    if (gameWon) {
      _endGame(winnerName: widget.myName);
    } else if (_availableMoves.isEmpty && !_hasAnyValidMove()) {
      _showFloatingMessage("כל המהלכים נוצלו — לחץ 'סיים תור'");
    }
  }

  void _handlePointTap(int index) {
    if (_currentTurnId != widget.myPlayFabId) return;
    if (_isActionLocked || _isRolling || _gameState != "playing" || !_hasRolledThisTurn) return;
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
          _selectedPoint = null; _validDestinations.clear();
        } else if (_validDestinations.contains(index)) {
          _executeMove(index);
        } else if (index >= 0 && _board[index] > 0 && _myBar == 0) {
          _selectedPoint = index;
          _validDestinations = _getValidDestinations(index);
        }
      }
    });
  }

  // ─── coins / xp ──────────────────────────────────────────────────────────
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
    _gameDuration = DateTime.now().difference(_gameStartTime);
    setState(() { _gameState = "gameOver"; _winnerIsMe = iWon; });
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
        body: json.encode({
          "Keys": ["TotalXP", "DailyGamesPlayed", "LastGameDate", "Wins", "Losses", "WinStreak", "BestWinStreak"]
        }),
      );

      int totalXp = 0, dailyGames = 0, wins = 0, losses = 0;
      int winStreak = 0, bestWinStreak = 0;
      String lastGameDate = '';

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data']?['Data'];
        totalXp     = int.tryParse(data?['TotalXP']?['Value']          ?? '0') ?? 0;
        dailyGames  = int.tryParse(data?['DailyGamesPlayed']?['Value'] ?? '0') ?? 0;
        wins        = int.tryParse(data?['Wins']?['Value']              ?? '0') ?? 0;
        losses      = int.tryParse(data?['Losses']?['Value']            ?? '0') ?? 0;
        winStreak   = int.tryParse(data?['WinStreak']?['Value']         ?? '0') ?? 0;
        bestWinStreak = int.tryParse(data?['BestWinStreak']?['Value']   ?? '0') ?? 0;
        lastGameDate = data?['LastGameDate']?['Value'] ?? '';
      }

      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      if (lastGameDate != today) dailyGames = 0;

      // update streak
      if (iWon) {
        winStreak++;
        if (winStreak > bestWinStreak) bestWinStreak = winStreak;
        wins++;
      } else {
        winStreak = 0;
        losses++;
      }

      // XP: win = 50 base + streak bonus (5 per consecutive win, max +50)
      //     loss = 25 base
      final isBoost = dailyGames < 5;
      final int streakBonus = iWon ? min(winStreak * 5, 50) : 0;
      final int baseXp = iWon ? 50 : 25;
      final int xpEarned = isBoost ? (baseXp + streakBonus) * 2 : (baseXp + streakBonus);
      final newTotalXP = totalXp + xpEarned;
      final newDailyGames = isBoost ? dailyGames + 1 : dailyGames;
      final levelBefore = _levelFromTotalXP(totalXp);
      final levelAfter = _levelFromTotalXP(newTotalXP);

      await http.post(
        Uri.parse('https://1A15A2.playfabapi.com/Client/UpdateUserData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "Data": {
            "TotalXP": newTotalXP.toString(),
            "DailyGamesPlayed": newDailyGames.toString(),
            "LastGameDate": today,
            "Wins": wins.toString(),
            "Losses": losses.toString(),
            "WinStreak": winStreak.toString(),
            "BestWinStreak": bestWinStreak.toString(),
          }
        }),
      );

      await http.post(
        Uri.parse('https://1A15A2.playfabapi.com/Client/UpdatePlayerStatistics'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "Statistics": [{"StatisticName": "TotalXP", "Value": newTotalXP}]
        }),
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
          _winStreak = winStreak;
          _bestWinStreak = bestWinStreak;
          _showWinScreen = true;
        });
        if (iWon) _coinFlyController.forward();
      }
    } catch (e) {
      debugPrint("Error in _awardXPAndCoins: $e");
      if (mounted) {
        setState(() { _showWinScreen = true; });
        if (iWon) _coinFlyController.forward();
      }
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
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
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: _buildCenterBoard(),
                      ),
                    ),
                    SizedBox(width: width * 0.18, child: _buildOpponentPanel()),
                  ],
                ),

                // opponent profile dialog overlay
                if (_showOpponentDialog) _buildOpponentProfileOverlay(width, height),

                // win screen overlay
                if (_showWinScreen) _buildWinScreen(width, height),

                // undo button
                if (_gameState == "playing" && _currentTurnId == widget.myPlayFabId &&
                    _moveHistory.isNotEmpty && !_isActionLocked)
                  Positioned(
                    bottom: height * 0.04,
                    left: width * 0.18 + 8,
                    child: GestureDetector(
                      onTap: _undoLastMove,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 1.5),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.undo, color: Colors.amber, size: 18),
                          SizedBox(width: 5),
                          Text("בטל צעד", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ),

                // end-turn button
                if (_gameState == "playing" && _currentTurnId == widget.myPlayFabId &&
                    _hasRolledThisTurn && (_availableMoves.isEmpty || !_hasAnyValidMove()) &&
                    !_isActionLocked)
                  Positioned(
                    bottom: height * 0.04,
                    right: width * 0.18 + 8,
                    child: GestureDetector(
                      onTap: _endTurn,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.greenAccent, width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3))],
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text("סיים תור", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ),

                // floating message
                if (_floatingMessage != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.7, end: 1.0),
                          duration: const Duration(milliseconds: 200),
                          builder: (ctx, scale, child) => Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.amber, width: 2.5),
                              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
                            ),
                            child: Text(_floatingMessage!,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center),
                          ),
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

  // ─── side panels ──────────────────────────────────────────────────────────
  Widget _buildMyPanel() {
    bool isMyTurn = _currentTurnId == widget.myPlayFabId && _gameState == "playing";
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 70, height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isMyTurn ? Colors.greenAccent : Colors.white, width: 3),
              boxShadow: isMyTurn
                  ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 14, spreadRadius: 2)]
                  : [],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 5),
          Text(widget.myName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ─ FLIP BOARD = RAGE QUIT button ─
          GestureDetector(
            onTap: _isRageQuitting ? null : _showFlipBoardDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B1500), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 8)],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_restaurant, color: Colors.white, size: 18),
                  SizedBox(height: 2),
                  Text("הפוך לוח", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          const Spacer(),
          if (isMyTurn) ...[
            Icon(Icons.hourglass_bottom,
                color: _timeLeft <= 10 ? Colors.red : Colors.white, size: 28),
            Text("$_timeLeft",
                style: TextStyle(
                    color: _timeLeft <= 10 ? Colors.red : Colors.white,
                    fontSize: 32, fontWeight: FontWeight.bold)),
          ] else
            const SizedBox(height: 60),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close, color: _myStrikes >= 1 ? Colors.red : Colors.grey.withValues(alpha: 0.5), size: 30),
              const SizedBox(width: 5),
              Icon(Icons.close, color: _myStrikes >= 2 ? Colors.red : Colors.grey.withValues(alpha: 0.5), size: 30),
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
      color: Colors.black.withValues(alpha: 0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showOpponentDialog = !_showOpponentDialog),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isOpponentTurn ? Colors.redAccent : Colors.white, width: 3),
                boxShadow: isOpponentTurn
                    ? [const BoxShadow(color: Colors.redAccent, blurRadius: 14, spreadRadius: 2)]
                    : [],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 5),
          Text(widget.opponentName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (isOpponentTurn) ...[
            Icon(Icons.hourglass_bottom,
                color: _timeLeft <= 10 ? Colors.red : Colors.white, size: 28),
            Text("$_timeLeft",
                style: TextStyle(
                    color: _timeLeft <= 10 ? Colors.red : Colors.white,
                    fontSize: 32, fontWeight: FontWeight.bold)),
          ] else
            const SizedBox(height: 60),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close, color: _opponentStrikes >= 1 ? Colors.red : Colors.grey.withValues(alpha: 0.5), size: 30),
              const SizedBox(width: 5),
              Icon(Icons.close, color: _opponentStrikes >= 2 ? Colors.red : Colors.grey.withValues(alpha: 0.5), size: 30),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── center board ─────────────────────────────────────────────────────────
  Widget _buildCenterBoard() {
    if (_gameState == "initialRoll") {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("הגרלת פתיחה",
                  style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(children: [const Text("אני", style: TextStyle(color: Colors.white)), const SizedBox(height: 8), _buildDiceWidget(_myInitialRoll)]),
                  const SizedBox(width: 50),
                  Column(children: [const Text("יריב", style: TextStyle(color: Colors.white)), const SizedBox(height: 8), _buildDiceWidget(_opponentInitialRoll)]),
                ],
              ),
              const SizedBox(height: 20),
              Text(_centerMessage, style: const TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 15),
              if (!_isRolling && _myInitialRoll == 0)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _rollInitialDice,
                  child: const Text("הטל קובייה",
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      );
    }

    // ── playing board, wrapped in rage-flip animation ──
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.5,
          child: AnimatedBuilder(
            animation: _rageController,
            builder: (ctx, child) {
              return Transform.translate(
                offset: Offset(_rageShakeAnim.value, 0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(_rageFlipAnim.value)
                    ..multiply(Matrix4.diagonal3Values(
                        _rageScaleAnim.value, _rageScaleAnim.value, 1.0)),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5C3A21), Color(0xFF8B5A2B), Color(0xFF5C3A21)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                border: Border.all(color: const Color(0xFF2E1C11), width: 3),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 10))],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEBCE),
                  border: Border.all(color: const Color(0xFF3E2723), width: 2),
                ),
                child: LayoutBuilder(
                  builder: (ctx, innerC) {
                    const double barW = 40, bornOffW = 55;
                    final double pointAreaW = innerC.maxWidth - barW - bornOffW;
                    final double pointW = pointAreaW / 12;
                    final double colH = (innerC.maxHeight - 42) / 2;
                    final double cs = min(pointW * 0.86, colH / 5.4).clamp(10.0, 36.0);
                    return _buildBoardRow(barW, bornOffW, cs);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── board layout ─────────────────────────────────────────────────────────
  Widget _buildBoardRow(double barW, double bornOffW, double cs) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(12 + i, isTop: true, cs: cs)))),
              SizedBox(height: 42, child: Center(child: _buildDiceArea(cs: cs))),
              Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(11 - i, isTop: false, cs: cs)))),
            ],
          ),
        ),
        _buildBar(barW, cs),
        Expanded(
          child: Column(
            children: [
              Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(18 + i, isTop: true, cs: cs)))),
              const SizedBox(height: 42),
              Expanded(child: Row(children: List.generate(6, (i) => _buildPoint(5 - i, isTop: false, cs: cs)))),
            ],
          ),
        ),
        _buildBorneOffArea(bornOffW, cs),
      ],
    );
  }

  // ─── bar widget ───────────────────────────────────────────────────────────
  Widget _buildBar(double barW, double cs) {
    final bool myBarFlash = _hitFlashBar == 1;
    return GestureDetector(
      onTap: () => _handlePointTap(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: barW,
        decoration: BoxDecoration(
          gradient: myBarFlash
              ? const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFBF360C)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter)
              : const LinearGradient(
                  colors: [Color(0xFF4A2F1D), Color(0xFF6B4226), Color(0xFF4A2F1D)]),
          border: const Border.symmetric(
              vertical: BorderSide(color: Color(0xFF2E1C11), width: 3)),
          boxShadow: [
            BoxShadow(
                color: myBarFlash
                    ? Colors.orange.withValues(alpha: 0.8)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: myBarFlash ? 12 : 5,
                spreadRadius: myBarFlash ? 3 : 1)
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (_oppBar > 0) ...List.generate(_oppBar, (i) => _buildChecker(false, size: cs)),
            if (_selectedPoint == 24)
              Container(
                  width: cs, height: cs,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width: 3))),
            if (_myBar > 0) ...List.generate(_myBar, (i) => _buildChecker(true, size: cs)),
          ],
        ),
      ),
    );
  }

  // ─── borne-off area ───────────────────────────────────────────────────────
  Widget _buildBorneOffArea(double bornOffW, double cs) {
    return GestureDetector(
      onTap: () => _handlePointTap(-1),
      child: Container(
        width: bornOffW,
        decoration: BoxDecoration(
          color: const Color(0xFF3E2723),
          border: const Border(left: BorderSide(color: Color(0xFF2E1C11), width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1, offset: const Offset(-2, 0))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_validDestinations.contains(-1))
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                color: Colors.greenAccent.withValues(alpha: 0.5),
                child: const Center(child: Icon(Icons.check, color: Colors.white, size: 20)),
              ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, color: Colors.white54, size: 16),
                    Text("יצאו\n$_myBorneOff",
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── single point ─────────────────────────────────────────────────────────
  Widget _buildPoint(int index, {required bool isTop, required double cs}) {
    int checkersCount = _board[index].abs();
    bool isMine = _board[index] > 0;
    bool isSelected = _selectedPoint == index;
    bool isTarget = _validDestinations.contains(index);
    bool isHighlighted = (_highlightFrom == index || _highlightTo == index);
    Color triangleColor = (index % 2 == (isTop ? 0 : 1))
        ? const Color(0xFFE8DCC4)
        : const Color(0xFF8B251D);

    return Expanded(
      child: GestureDetector(
        onTap: () => _handlePointTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isTarget
                ? Colors.green.withValues(alpha: 0.35)
                : isHighlighted
                    ? Colors.orange.withValues(alpha: 0.28)
                    : Colors.transparent,
            border: isTarget
                ? Border.all(color: Colors.greenAccent, width: 1.5)
                : isHighlighted
                    ? Border.all(color: Colors.orangeAccent, width: 2.0)
                    : null,
            boxShadow: isHighlighted
                ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 2)]
                : isTarget
                    ? [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 8)]
                    : null,
          ),
          child: CustomPaint(
            painter: TrianglePainter(triangleColor, isTop),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Column(
                mainAxisAlignment: isTop ? MainAxisAlignment.start : MainAxisAlignment.end,
                children: List.generate(checkersCount > 5 ? 5 : checkersCount, (i) {
                  if (i == 4 && checkersCount > 5) {
                    return _buildChecker(isMine, isSelected: isSelected && i == 4, extraCount: checkersCount - 4, size: cs);
                  }
                  return _buildChecker(isMine, isSelected: isSelected && i == checkersCount - 1, size: cs);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── checker widget ───────────────────────────────────────────────────────
  Widget _buildChecker(bool isMine, {bool isSelected = false, int extraCount = 0, double size = 30}) {
    final checkerWidget = Container(
      margin: EdgeInsets.symmetric(vertical: size * 0.06),
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isMine
              ? [Colors.white, Colors.grey.shade300]
              : [const Color(0xFF777777), const Color(0xFF111111)],
          center: const Alignment(-0.3, -0.3),
          radius: 0.85,
        ),
        border: Border.all(
          color: isSelected ? Colors.yellow : (isMine ? Colors.grey.shade400 : Colors.black87),
          width: isSelected ? 3 : 1.5,
        ),
        boxShadow: [
          if (isSelected) ...[
            const BoxShadow(color: Colors.yellow, blurRadius: 12, spreadRadius: 4),
            const BoxShadow(color: Colors.orange, blurRadius: 6, spreadRadius: 2),
          ],
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 3, offset: const Offset(1, 2)),
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
              ? Center(child: Text("+$extraCount",
                  style: TextStyle(color: isMine ? Colors.black : Colors.white,
                      fontSize: size * 0.3, fontWeight: FontWeight.bold)))
              : null,
        ),
      ),
    );

    if (isSelected) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (ctx, child) => Transform.scale(scale: _pulseScale.value, child: child),
        child: checkerWidget,
      );
    }
    return checkerWidget;
  }

  // ─── dice area ────────────────────────────────────────────────────────────
  Widget _buildDiceArea({double cs = 30}) {
    final double diceSize = (cs * 1.15).clamp(24.0, 40.0);

    if (_currentTurnId == widget.myPlayFabId) {
      // Show rolling animation (actual die values) as soon as roll starts
      if (_isRolling) return _buildDiceRow(diceSize);
      if (!_hasRolledThisTurn) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Opacity(opacity: 0.35, child: _buildDiceWidget(0, size: diceSize)),
          const SizedBox(width: 5),
          Opacity(opacity: 0.35, child: _buildDiceWidget(0, size: diceSize)),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 6, shadowColor: Colors.amber,
            ),
            onPressed: _isActionLocked ? null : _rollPlayingDice,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.casino, color: Colors.black, size: 16),
              SizedBox(width: 4),
              Text("זרוק", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ),
        ]);
      }
      return _buildDiceRow(diceSize);
    }

    // opponent's turn
    if (!_hasRolledThisTurn && !_isRolling) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Opacity(opacity: 0.35, child: _buildDiceWidget(0, size: diceSize)),
        const SizedBox(width: 8),
        Opacity(opacity: 0.35, child: _buildDiceWidget(0, size: diceSize)),
      ]);
    }
    return _buildDiceRow(diceSize);
  }

  // ─── dice row (2 dice, with ×N badge for doubles) ─────────────────────────
  Widget _buildDiceRow(double diceSize) {
    if (_die1 == _die2 && _hasRolledThisTurn) {
      // Doubles: 2 dice, each can be used twice → show ×N badge
      final int remaining = _availableMoves.where((m) => m == _die1).length;
      // Die 1 covers uses 1+2 (remaining 4→3→2), Die 2 covers uses 3+4 (remaining 2→1→0)
      final bool die1Consumed = remaining <= 2;
      final bool die2Consumed = remaining <= 0;
      final int die1Badge = die1Consumed ? 0 : (remaining == 4 ? 2 : 1);
      final int die2Badge = die2Consumed ? 0 : (remaining >= 3 ? 2 : 1);

      return Row(mainAxisSize: MainAxisSize.min, children: [
        _buildDiceWidget(_die1, size: diceSize, consumed: die1Consumed, badge: die1Badge),
        const SizedBox(width: 8),
        _buildDiceWidget(_die2, size: diceSize, consumed: die2Consumed, badge: die2Badge),
      ]);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      _buildDiceWidget(_die1, size: diceSize,
          consumed: _hasRolledThisTurn && !_availableMoves.contains(_die1)),
      const SizedBox(width: 8),
      _buildDiceWidget(_die2, size: diceSize,
          consumed: _hasRolledThisTurn && !_availableMoves.contains(_die2)),
    ]);
  }

  // ─── dice pip positions ───────────────────────────────────────────────────
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
          child: Container(width: r * 2, height: r * 2,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A1A1A))),
        )).toList(),
      ),
    );
  }

  // ─── dice widget (with shake + optional ×N badge) ─────────────────────────
  Widget _buildDiceWidget(int value, {double size = 50, bool consumed = false, int badge = 0}) {
    final diceBody = Container(
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
          BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 2, offset: const Offset(-1, -1)),
        ],
      ),
      child: value == 0
          ? Center(child: Icon(Icons.casino_outlined, color: Colors.white54, size: size * 0.55))
          : _buildDicePips(value, size),
    );

    // badge overlay (×N for doubles)
    Widget diceWithBadge = Stack(
      clipBehavior: Clip.none,
      children: [
        diceBody,
        if (badge > 0 && !consumed)
          Positioned(
            right: -4, bottom: -4,
            child: Container(
              width: size * 0.42, height: size * 0.42,
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black54, width: 1),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
              ),
              child: Center(
                child: Text("×$badge",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: size * 0.18,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );

    final opacity = Opacity(opacity: consumed ? 0.28 : 1.0, child: diceWithBadge);

    if (_isRolling && !consumed) {
      return AnimatedBuilder(
        animation: _diceController,
        builder: (ctx, child) => Transform.translate(
          offset: Offset(_diceShakeX.value, 0),
          child: Transform.rotate(angle: _diceRotation.value, child: child),
        ),
        child: opacity,
      );
    }
    return opacity;
  }

  // ─── opponent profile overlay ─────────────────────────────────────────────
  Widget _buildOpponentProfileOverlay(double width, double height) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: width * 0.28,
      child: GestureDetector(
        onTap: () => setState(() => _showOpponentDialog = false),
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // prevent tap-through
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 2),
                    ),
                    child: const Icon(Icons.person, color: Colors.white70, size: 40),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.opponentName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                    const SizedBox(width: 5),
                    Text("${widget.opponentTrophies}",
                        style: const TextStyle(color: Colors.amber, fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => setState(() => _showOpponentDialog = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text("סגור",
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
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

  // ─── win/loss screen ──────────────────────────────────────────────────────
  Widget _buildWinScreen(double width, double height) {
    final coinsAwarded = _winnerIsMe ? widget.betAmount * 2 : 0;
    final winnerLabel = _winnerIsMe ? widget.myName : widget.opponentName;
    final didLevelUp = _levelAfter > _levelBefore;
    final xpNeeded = _xpNeededForLevel(_levelAfter);
    final xpInLevel = _xpInCurrentLevel(_totalXpAfter, _levelAfter);
    final progressFraction = xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 0.0;

    // format game duration
    final mins = _gameDuration.inMinutes;
    final secs = _gameDuration.inSeconds % 60;
    final durationStr = "$mins:${secs.toString().padLeft(2, '0')}";

    return Positioned.fill(
      child: Stack(
        children: [
          // semi-transparent backdrop (board visible behind)
          Container(color: Colors.black.withValues(alpha: 0.65)),

          // flying coins animation (winner only)
          if (_winnerIsMe)
            AnimatedBuilder(
              animation: _coinFlyAnim,
              builder: (ctx, _) {
                return Stack(
                  children: List.generate(6, (i) {
                    final xFrac = 0.12 + i * 0.15;
                    final yStart = height * 0.9;
                    final yEnd = height * 0.1;
                    final delay = i * 0.12;
                    final progress = (_coinFlyAnim.value - delay).clamp(0.0, 1.0);
                    final yPos = yStart - (yStart - yEnd) * progress;
                    return Positioned(
                      left: width * xFrac,
                      top: yPos,
                      child: Opacity(
                        opacity: progress < 0.85 ? 1.0 : (1.0 - progress) / 0.15,
                        child: const Icon(Icons.monetization_on,
                            color: Colors.amber, size: 28),
                      ),
                    );
                  }),
                );
              },
            ),

          Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.55, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (ctx, scale, child) => Transform.scale(scale: scale, child: child),
            child: SingleChildScrollView(
              child: Container(
                width: width * 0.68,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A192F), Color(0xFF1A3A5C)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.amber, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 5)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // trophy / sad icon
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.5, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      builder: (ctx, s, child) => Transform.scale(scale: s, child: child),
                      child: Icon(
                        _winnerIsMe ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                        color: _winnerIsMe ? Colors.amber : Colors.grey,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _winnerIsMe ? "ניצחת!" : "הפסדת",
                      style: TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold,
                          color: _winnerIsMe ? Colors.amber : Colors.white60),
                    ),
                    Text(winnerLabel, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    const SizedBox(height: 16),

                    // ── game summary row ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _summaryTile(Icons.timer_outlined, durationStr, "זמן"),
                          _summaryDivider(),
                          _summaryTile(Icons.check_circle_outline, "$_myBorneOff / 15", "יצאו"),
                          _summaryDivider(),
                          _summaryTile(
                            Icons.local_fire_department,
                            "$_winStreak",
                            "רצף ניצחונות",
                            color: _winStreak >= 3 ? Colors.orangeAccent : Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── win streak banner ──
                    if (_winnerIsMe && _winStreak > 1)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.5), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.white, size: 22),
                            const SizedBox(width: 6),
                            Text("רצף של $_winStreak ניצחונות!",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            if (_winStreak == _bestWinStreak && _bestWinStreak > 1) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                                child: const Text("שיא!", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // ── coins (winner only) ──
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
                            Text("+$coinsAwarded מטבעות",
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        ),
                      ),

                    // ── XP ──
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
                              Text("+$_xpEarned XP",
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
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
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: progressFraction),
                              duration: const Duration(milliseconds: 900),
                              builder: (ctx, val, _) => LinearProgressIndicator(
                                value: val,
                                backgroundColor: Colors.grey[700],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                                minHeight: 7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text("רמה $_levelAfter  •  $xpInLevel / $xpNeeded XP",
                              style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        ],
                      ),
                    ),

                    // ── level-up banner ──
                    if (didLevelUp) ...[
                      const SizedBox(height: 12),
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
                            Text("עלית לרמה $_levelAfter!",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // ── action buttons ──
                    Row(
                      children: [
                        // Play Again
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              elevation: 4,
                            ),
                            onPressed: () {
                              if (_isBotMatch) {
                                Navigator.pop(context); // back to pre-game
                              } else {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            },
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.replay, color: Colors.white, size: 22),
                                SizedBox(height: 3),
                                Text("שחק שוב", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Home
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _winnerIsMe ? Colors.amber : Colors.blueGrey,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.home, color: _winnerIsMe ? Colors.black : Colors.white, size: 22),
                                const SizedBox(height: 3),
                                Text("בית",
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.bold,
                                        color: _winnerIsMe ? Colors.black : Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }

  Widget _summaryTile(IconData icon, String value, String label, {Color color = Colors.white70}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _summaryDivider() => Container(
    width: 1, height: 36,
    color: Colors.white.withValues(alpha: 0.15),
  );
}

// ─── triangle painter ─────────────────────────────────────────────────────
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
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(TrianglePainter old) => old.color != color || old.isTop != isTop;
}

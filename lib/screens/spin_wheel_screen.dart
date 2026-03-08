import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

// ─── Prize Model ─────────────────────────────────────────────────────────────

class _Prize {
  final String label;      // text shown on wheel
  final int coins;
  final int tickets;
  final int weight;        // out of 100
  final Color color;

  const _Prize({
    required this.label,
    required this.coins,
    required this.tickets,
    required this.weight,
    required this.color,
  });

  String get displayName {
    if (coins > 0) return '$coins מטבעות';
    return '$tickets פתק${tickets > 1 ? 'ים' : ''}';
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class SpinWheelScreen extends StatefulWidget {
  final String sessionTicket;
  final String playFabId;

  const SpinWheelScreen({
    super.key,
    required this.sessionTicket,
    required this.playFabId,
  });

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  static const String _titleId = "1A15A2";
  static const int _maxDailySpins = 5;

  // Prizes — weights must sum to 100
  static const List<_Prize> _prizes = [
    _Prize(label: '50\nמטבעות',  coins: 50,  tickets: 0, weight: 50, color: Color(0xFF4A90D9)),
    _Prize(label: '100\nמטבעות', coins: 100, tickets: 0, weight: 25, color: Color(0xFF7B68EE)),
    _Prize(label: '200\nמטבעות', coins: 200, tickets: 0, weight: 12, color: Color(0xFF20B2AA)),
    _Prize(label: 'פתק\nX1',     coins: 0,   tickets: 1, weight: 8,  color: Color(0xFFFFD700)),
    _Prize(label: '500\nמטבעות', coins: 500, tickets: 0, weight: 3,  color: Color(0xFFFF6B35)),
    _Prize(label: 'פתקים\nX5',   coins: 0,   tickets: 5, weight: 2,  color: Color(0xFFE040FB)),
  ];

  final StreamController<int> _wheelController = StreamController<int>();

  bool _isSpinning  = false;
  bool _isLoading   = true;
  int  _spinsToday  = 0;
  String _monthlyWinner = '';
  int  _selectedIndex = 0;

  // Glow animation for spin button
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  int get _spinsRemaining => (_maxDailySpins - _spinsToday).clamp(0, _maxDailySpins);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _wheelController.close();
    _glowController.dispose();
    super.dispose();
  }

  // ─── Weighted random ───────────────────────────────────────────────────────

  int _weightedRandom() {
    final r = Random().nextInt(100);
    int cumulative = 0;
    for (int i = 0; i < _prizes.length; i++) {
      cumulative += _prizes[i].weight;
      if (r < cumulative) return i;
    }
    return 0;
  }

  // ─── PlayFab data load ────────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final headers = {
        'Content-Type': 'application/json',
        'X-Authorization': widget.sessionTicket,
      };
      final results = await Future.wait([
        http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/GetUserData'),
          headers: headers,
          body: json.encode({"Keys": ["LastSpinDate", "SpinsToday"]}),
        ),
        http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/GetTitleData'),
          headers: headers,
          body: json.encode({"Keys": ["MonthlyWinner"]}),
        ),
      ]);

      if (!mounted) return;

      final userData  = json.decode(results[0].body)['data']?['Data'];
      final titleData = json.decode(results[1].body)['data']?['Data'];

      final today     = _todayUtc();
      final lastDate  = userData?['LastSpinDate']?['Value'] ?? '';
      int spinsToday  = int.tryParse(userData?['SpinsToday']?['Value'] ?? '0') ?? 0;
      if (lastDate != today) spinsToday = 0; // reset on new day

      // Monthly winner can be a JSON object or plain string
      String winner = '';
      final rawWinner = titleData?['MonthlyWinner'] ?? '';
      if (rawWinner.isNotEmpty) {
        try {
          final parsed = json.decode(rawWinner);
          winner = parsed is Map ? (parsed['username'] ?? '') : rawWinner;
        } catch (_) {
          winner = rawWinner;
        }
      }

      setState(() {
        _spinsToday    = spinsToday;
        _monthlyWinner = winner;
        _isLoading     = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Spin logic ───────────────────────────────────────────────────────────

  void _spin() {
    if (_isSpinning || _spinsRemaining <= 0) return;
    final result = _weightedRandom();
    setState(() {
      _isSpinning    = true;
      _selectedIndex = result;
    });
    _wheelController.add(result);
  }

  Future<void> _onAnimationEnd() async {
    final prize   = _prizes[_selectedIndex];
    final today   = _todayUtc();
    final newCount = _spinsToday + 1;

    // Fire-and-forget PlayFab calls
    _awardPrize(prize);
    _saveSpinData(today, newCount);

    if (!mounted) return;
    setState(() {
      _isSpinning = false;
      _spinsToday = newCount;
    });
    _showPrizeDialog(prize);
  }

  Future<void> _awardPrize(_Prize prize) async {
    if (widget.sessionTicket.isEmpty) return;
    final headers = {
      'Content-Type': 'application/json',
      'X-Authorization': widget.sessionTicket,
    };
    try {
      if (prize.coins > 0) {
        await http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/AddUserVirtualCurrency'),
          headers: headers,
          body: json.encode({"VirtualCurrency": "CO", "Amount": prize.coins}),
        );
      }
      if (prize.tickets > 0) {
        await http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/AddUserVirtualCurrency'),
          headers: headers,
          body: json.encode({"VirtualCurrency": "TK", "Amount": prize.tickets}),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveSpinData(String date, int count) async {
    if (widget.sessionTicket.isEmpty) return;
    try {
      await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/UpdateUserData'),
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': widget.sessionTicket,
        },
        body: json.encode({
          "Data": {
            "LastSpinDate": date,
            "SpinsToday": "$count",
          }
        }),
      );
    } catch (_) {}
  }

  void _watchAdForSpin() {
    // Integrate AdMob / Unity Ads here; on success call _addBonusSpin()
    // For now shows a placeholder snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('תכונת הסרטון תהיה זמינה בקרוב!', textAlign: TextAlign.right),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'בדוק',
          textColor: Colors.white,
          onPressed: _addBonusSpin,
        ),
      ),
    );
  }

  void _addBonusSpin() {
    setState(() => _spinsToday = (_spinsToday - 1).clamp(0, _maxDailySpins));
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  void _showPrizeDialog(_Prize prize) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                prize.tickets > 0 ? '🎟️' : '🪙',
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 12),
              const Text(
                'מזל טוב! זכית ב:',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: prize.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: prize.color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: prize.color.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  prize.displayName,
                  style: TextStyle(
                    color: prize.color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: prize.color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'כיף!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOddsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent, size: 22),
              SizedBox(width: 10),
              Text(
                'טבלת הסיכויים',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: Colors.white12),
              const SizedBox(height: 6),
              for (final prize in _prizes) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: prize.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${prize.weight}%',
                          style: TextStyle(
                            color: prize.color,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          prize.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: prize.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(color: Colors.white12),
              const SizedBox(height: 6),
              const Text(
                'הגלגל מגריל את התוצאה לפני האנימציה.\nכל סיבוב עצמאי לחלוטין.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('הבנתי', style: TextStyle(color: Colors.blueAccent, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _todayUtc() =>
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Image.asset(
              'assets/background_dark.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (ctx, err, st) => Container(color: const Color(0xFF0A192F)),
            ),
            Container(color: Colors.black.withValues(alpha: 0.5)),
            SafeArea(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    )
                  : Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildWheel()),
                        _buildBottomSection(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFFD700)],
                  ).createShader(bounds),
                  child: const Text(
                    '🎰 הגרלת 100 ש״ח!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Text(
                  'כל פתק הגרלה מגדיל את הסיכוי שלך לזכות',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                if (_monthlyWinner.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 13),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'זוכה חודש שעבר: $_monthlyWinner',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _showOddsDialog,
            icon: const Icon(Icons.info_outline, color: Colors.white54, size: 26),
            tooltip: 'טבלת סיכויים',
          ),
        ],
      ),
    );
  }

  // ─── Fortune Wheel ────────────────────────────────────────────────────────

  Widget _buildWheel() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight) - 32;
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: FortuneWheel(
              selected: _wheelController.stream,
              animateFirst: false,
              duration: const Duration(seconds: 5),
              onAnimationEnd: _onAnimationEnd,
              indicators: const [
                FortuneIndicator(
                  alignment: Alignment.topCenter,
                  child: TriangleIndicator(
                    color: Colors.white,
                    width: 22,
                    height: 28,
                  ),
                ),
              ],
              items: [
                for (final prize in _prizes)
                  FortuneItem(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        prize.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    style: FortuneItemStyle(
                      color: prize.color,
                      borderColor: Colors.white,
                      borderWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Bottom Controls ──────────────────────────────────────────────────────

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Remaining spins row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'סיבובים נותרים היום: ',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              Text(
                '$_spinsRemaining',
                style: TextStyle(
                  color: _spinsRemaining > 0 ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / $_maxDailySpins',
                style: const TextStyle(color: Colors.white38, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _maxDailySpins,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 13,
                height: 13,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _spinsRemaining
                      ? Colors.greenAccent
                      : Colors.white24,
                  boxShadow: i < _spinsRemaining
                      ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 6)]
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Spin button
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (ctx, child) {
              final canSpin = !_isSpinning && _spinsRemaining > 0;
              return Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: canSpin
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: _glowAnim.value * 0.7),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isSpinning || _spinsRemaining <= 0) ? null : _spin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: _isSpinning
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: Colors.black54,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        _spinsRemaining > 0 ? '🎰  סובב עכשיו!' : 'חזור מחר לסיבובים נוספים',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: _spinsRemaining > 0 ? Colors.black : Colors.white38,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Watch video button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isSpinning ? null : _watchAdForSpin,
              icon: const Icon(Icons.ondemand_video, size: 18),
              label: const Text('צפה בסרטון לסיבוב נוסף'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                disabledForegroundColor: Colors.white24,
                side: BorderSide(
                  color: _isSpinning ? Colors.white12 : Colors.amber.withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

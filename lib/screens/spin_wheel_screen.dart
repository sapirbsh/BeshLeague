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

  bool _isSpinning     = false;
  bool _isLoading      = true;
  int  _spinsAvailable = 0;   // spins in bank (watch ad to earn, spend to spin)
  int  _adsWatched     = 0;   // total ads watched today (cap = _maxDailySpins)
  String _monthlyWinner = '';
  int  _selectedIndex = 0;

  // Glow animation for spin button
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  bool get _canEarnMore => _adsWatched < _maxDailySpins;

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

      final today    = _todayUtc();
      final lastDate = userData?['LastSpinDate']?['Value'] ?? '';
      // Reset on new day
      int adsWatched     = lastDate == today ? (int.tryParse(userData?['AdsWatched']?['Value']     ?? '0') ?? 0) : 0;
      int spinsAvailable = lastDate == today ? (int.tryParse(userData?['SpinsAvailable']?['Value'] ?? '0') ?? 0) : 0;

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
        _adsWatched     = adsWatched;
        _spinsAvailable = spinsAvailable;
        _monthlyWinner  = winner;
        _isLoading      = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Spin logic ───────────────────────────────────────────────────────────

  void _spin() {
    if (_isSpinning || _spinsAvailable <= 0) return;
    final result = _weightedRandom();
    setState(() {
      _isSpinning    = true;
      _selectedIndex = result;
    });
    _wheelController.add(result);
  }

  Future<void> _onAnimationEnd() async {
    final prize = _prizes[_selectedIndex];
    final today = _todayUtc();
    final newAvailable = _spinsAvailable - 1;

    // Fire-and-forget PlayFab calls
    _awardPrize(prize);
    _saveSpinData(today, _adsWatched, newAvailable);

    if (!mounted) return;
    setState(() {
      _isSpinning     = false;
      _spinsAvailable = newAvailable;
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

  Future<void> _saveSpinData(String date, int adsWatched, int spinsAvailable) async {
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
            "LastSpinDate":    date,
            "AdsWatched":      "$adsWatched",
            "SpinsAvailable":  "$spinsAvailable",
          }
        }),
      );
    } catch (_) {}
  }

  void _watchAdForSpin() {
    if (!_canEarnMore || _isSpinning) return;
    // TODO: Integrate AdMob / Unity Ads here; call _onAdCompleted() on success
    // Simulating ad completion for now:
    _onAdCompleted();
  }

  void _onAdCompleted() {
    if (!_canEarnMore) return;
    final today       = _todayUtc();
    final newAds      = _adsWatched + 1;
    final newAvailable = _spinsAvailable + 1;
    setState(() {
      _adsWatched     = newAds;
      _spinsAvailable = newAvailable;
    });
    _saveSpinData(today, newAds, newAvailable);
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
                  : Stack(
                      children: [
                        // Wheel fills entire area
                        Positioned.fill(child: _buildWheel()),
                        // Header overlaid on top
                        Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),
                        // Controls overlaid at bottom
                        Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomSection()),
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
        // Leave room for header (~80px) and bottom controls (~130px)
        final availableH = constraints.maxHeight - 210;
        final size = min(constraints.maxWidth - 16, availableH.clamp(100.0, constraints.maxHeight)).toDouble();
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 80, bottom: 130),
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
          ),
        );
      },
    );
  }

  // ─── Bottom Controls ──────────────────────────────────────────────────────

  Widget _buildBottomSection() {
    final canSpin = !_isSpinning && _spinsAvailable > 0;
    final canWatch = !_isSpinning && _canEarnMore;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spins available + dot indicators in one row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'סיבובים: $_spinsAvailable  ',
                style: TextStyle(
                  color: _spinsAvailable > 0 ? Colors.greenAccent : Colors.white38,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...List.generate(_maxDailySpins, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _adsWatched ? Colors.amber : Colors.white24,
                  boxShadow: i < _adsWatched
                      ? [const BoxShadow(color: Colors.amber, blurRadius: 5)]
                      : null,
                ),
              )),
              Text(
                '  $_adsWatched/$_maxDailySpins פרסומות',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Spin button
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (ctx, child) => Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: canSpin
                    ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: _glowAnim.value * 0.7), blurRadius: 18, spreadRadius: 3)]
                    : null,
              ),
              child: child,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canSpin ? _spin : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSpinning
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 3))
                    : Text(
                        canSpin ? '🎰  סובב עכשיו!' : (_spinsAvailable == 0 ? 'צפה בפרסומת לסיבוב' : 'צפה בפרסומת'),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: canSpin ? Colors.black : Colors.white38),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Watch ad button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: canWatch ? _watchAdForSpin : null,
              icon: Icon(Icons.ondemand_video, size: 16, color: canWatch ? Colors.amber : Colors.white24),
              label: Text(
                _canEarnMore ? 'צפה בפרסומת לקבלת סיבוב' : 'הגעת למקסימום סיבובים היום',
                style: TextStyle(fontSize: 13, color: canWatch ? Colors.amber : Colors.white24),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: canWatch ? Colors.amber.withValues(alpha: 0.6) : Colors.white12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

// ─── Prize Model ─────────────────────────────────────────────────────────────

class _Prize {
  final String label;
  final int coins;
  final int tickets;
  final int weight;
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

  String get emoji => tickets > 0 ? '🎟️' : '🪙';
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
  int  _spinsAvailable = 0;
  int  _adsWatched     = 0;
  String _monthlyWinner = '';
  int  _selectedIndex  = 0;
  _Prize? _wonPrize;

  // Glow animation for spin button
  late AnimationController _glowController;
  late Animation<double>   _glowAnim;

  bool get _canEarnMore => _adsWatched < _maxDailySpins;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
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

  // ─── Weighted random ────────────────────────────────────────────────────────

  int _weightedRandom() {
    final r = Random().nextInt(100);
    int cumulative = 0;
    for (int i = 0; i < _prizes.length; i++) {
      cumulative += _prizes[i].weight;
      if (r < cumulative) return i;
    }
    return 0;
  }

  // ─── PlayFab ────────────────────────────────────────────────────────────────

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
          body: json.encode({"Keys": ["LastSpinDate", "AdsWatched", "SpinsAvailable"]}),
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
      int adsWatched     = lastDate == today ? (int.tryParse(userData?['AdsWatched']?['Value']     ?? '0') ?? 0) : 0;
      int spinsAvailable = lastDate == today ? (int.tryParse(userData?['SpinsAvailable']?['Value'] ?? '0') ?? 0) : 0;

      String winner = '';
      final rawWinner = titleData?['MonthlyWinner'] ?? '';
      if (rawWinner.isNotEmpty) {
        try {
          final parsed = json.decode(rawWinner);
          winner = parsed is Map ? (parsed['username'] ?? '') : rawWinner;
        } catch (_) { winner = rawWinner; }
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

  Future<void> _saveSpinData(String date, int adsWatched, int spinsAvailable) async {
    if (widget.sessionTicket.isEmpty) return;
    try {
      await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/UpdateUserData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"Data": {
          "LastSpinDate":   date,
          "AdsWatched":     "$adsWatched",
          "SpinsAvailable": "$spinsAvailable",
        }}),
      );
    } catch (_) {}
  }

  Future<void> _awardPrize(_Prize prize) async {
    if (widget.sessionTicket.isEmpty) return;
    try {
      if (prize.coins > 0) {
        await http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/AddUserVirtualCurrency'),
          headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
          body: json.encode({"VirtualCurrency": "CO", "Amount": prize.coins}),
        );
      }
      if (prize.tickets > 0) {
        await http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/AddUserVirtualCurrency'),
          headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
          body: json.encode({"VirtualCurrency": "TK", "Amount": prize.tickets}),
        );
      }
    } catch (_) {}
  }

  // ─── Spin logic ─────────────────────────────────────────────────────────────

  void _spin() {
    if (_isSpinning || _spinsAvailable <= 0) return;
    final result = _weightedRandom();
    setState(() {
      _isSpinning    = true;
      _selectedIndex = result;
      _wonPrize      = null;
    });
    _wheelController.add(result);
  }

  void _onAnimationEnd() {
    final prize    = _prizes[_selectedIndex];
    final today    = _todayUtc();
    final newAvail = _spinsAvailable - 1;

    _awardPrize(prize);
    _saveSpinData(today, _adsWatched, newAvail);

    if (!mounted) return;
    setState(() {
      _isSpinning     = false;
      _spinsAvailable = newAvail;
      _wonPrize       = prize;
    });
  }

  void _watchAdForSpin() {
    if (!_canEarnMore || _isSpinning) return;
    // TODO: replace with real AdMob call; on ad completion call _onAdCompleted()
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

  String _todayUtc() => DateTime.now().toUtc().toIso8601String().substring(0, 10);

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            // Background
            Image.asset(
              'assets/background_dark.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (ctx, err, st) => Container(color: const Color(0xFF0A192F)),
            ),
            Container(color: Colors.black.withValues(alpha: 0.45)),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildWheelSection()),
                        _buildControls(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFFD700)],
                  ).createShader(b),
                  child: const Text('🎰 גלגל המזל',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                if (_monthlyWinner.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 12),
                    const SizedBox(width: 4),
                    Flexible(child: Text('זוכה חודש שעבר: $_monthlyWinner',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                        overflow: TextOverflow.ellipsis)),
                  ]),
              ],
            ),
          ),
          IconButton(
            onPressed: _showOddsDialog,
            icon: const Icon(Icons.info_outline, color: Colors.white54, size: 24),
          ),
        ],
      ),
    );
  }

  // ─── Wheel + prize overlay ───────────────────────────────────────────────────

  Widget _buildWheelSection() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight) * 0.95;
        return Stack(
          alignment: Alignment.center,
          children: [
            // The big fortune wheel
            Center(
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
                      child: TriangleIndicator(color: Colors.white, width: 26, height: 32),
                    ),
                  ],
                  items: [
                    for (final prize in _prizes)
                      FortuneItem(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            prize.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        style: FortuneItemStyle(
                          color: prize.color,
                          borderColor: Colors.white,
                          borderWidth: 2.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Prize pop-up overlay (shown after spin)
            if (_wonPrize != null && !_isSpinning)
              Positioned(
                bottom: size * 0.05,
                child: _buildPrizeOverlay(_wonPrize!),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPrizeOverlay(_Prize prize) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (ctx, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: prize.color.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(color: prize.color.withValues(alpha: 0.6), blurRadius: 24, spreadRadius: 4),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prize.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text('🎉 מזל טוב! זכית ב:', style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text(prize.displayName,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => setState(() => _wonPrize = null),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: prize.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              ),
              child: const Text('אסוף פרס!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom controls ────────────────────────────────────────────────────────

  Widget _buildControls() {
    final canSpin  = !_isSpinning && _spinsAvailable > 0 && _wonPrize == null;
    final canWatch = !_isSpinning && _canEarnMore && _wonPrize == null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spins available + ad progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('סיבובים: $_spinsAvailable  ',
                  style: TextStyle(
                    color: _spinsAvailable > 0 ? Colors.greenAccent : Colors.white38,
                    fontSize: 14, fontWeight: FontWeight.bold,
                  )),
              ...List.generate(_maxDailySpins, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10, height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _adsWatched ? Colors.amber : Colors.white24,
                  boxShadow: i < _adsWatched
                      ? [const BoxShadow(color: Colors.amber, blurRadius: 5)]
                      : null,
                ),
              )),
              Text('  $_adsWatched/$_maxDailySpins פרסומות',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          // Spin button
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (ctx, child) => Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: canSpin
                    ? [BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: _glowAnim.value * 0.8),
                        blurRadius: 20, spreadRadius: 4)]
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
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 3))
                    : Text(
                        canSpin ? '🎰  סובב עכשיו!' : (_wonPrize != null ? 'אסוף את הפרס תחילה' : 'צפה בפרסומת לסיבוב'),
                        style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold,
                          color: canSpin ? Colors.black : Colors.white38,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Watch ad button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: canWatch ? _watchAdForSpin : null,
              icon: Icon(Icons.ondemand_video, size: 16,
                  color: canWatch ? Colors.amber : Colors.white24),
              label: Text(
                _canEarnMore ? 'צפה בפרסומת לקבלת סיבוב' : 'הגעת למקסימום סיבובים היום',
                style: TextStyle(fontSize: 12, color: canWatch ? Colors.amber : Colors.white24),
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

  // ─── Odds dialog ────────────────────────────────────────────────────────────

  void _showOddsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blueAccent, size: 22),
            SizedBox(width: 10),
            Text('טבלת הסיכויים',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final prize in _prizes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: prize.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${prize.weight}%',
                            style: TextStyle(color: prize.color, fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(prize.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 14))),
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: prize.color, shape: BoxShape.circle),
                      ),
                    ],
                  ),
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
}

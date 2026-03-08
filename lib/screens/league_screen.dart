import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class LeagueScreen extends StatefulWidget {
  final String sessionTicket;
  final String playFabId;

  const LeagueScreen({
    super.key,
    required this.sessionTicket,
    required this.playFabId,
  });

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  static const _titleId = "1A15A2";

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _activeLeague;
  bool _hasTicket = false;
  int _coins = 0;

  Timer? _countdownTimer;
  Duration _timeUntilStart = Duration.zero;
  bool _leagueStarted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _countdownTimer?.cancel();
    });

    try {
      final headers = {
        'Content-Type': 'application/json',
        'X-Authorization': widget.sessionTicket,
      };

      final results = await Future.wait([
        http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/GetTitleData'),
          headers: headers,
          body: json.encode({"Keys": ["ActiveLeagues"]}),
        ),
        http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/GetUserInventory'),
          headers: headers,
          body: '{}',
        ),
      ]);

      final titleRes = results[0];
      final inventoryRes = results[1];

      // Parse leagues
      Map<String, dynamic>? foundLeague;
      if (titleRes.statusCode == 200) {
        final raw = json.decode(titleRes.body)['data']?['Data']?['ActiveLeagues'];
        if (raw != null && raw.toString().isNotEmpty) {
          final List<dynamic> leagues = json.decode(raw.toString());
          final now = DateTime.now().toUtc();
          for (final league in leagues) {
            final saleDateStr = league['saleStartDate']?.toString() ?? '';
            if (saleDateStr.isEmpty) continue;
            final saleDate = DateTime.tryParse(saleDateStr)?.toUtc();
            if (saleDate != null && !now.isBefore(saleDate)) {
              foundLeague = Map<String, dynamic>.from(league);
              break;
            }
          }
        }
      }

      // Parse inventory + coins
      bool hasTicket = false;
      int fetchedCoins = 0;
      if (inventoryRes.statusCode == 200) {
        final data = json.decode(inventoryRes.body)['data'];
        final vc = data?['VirtualCurrency'] as Map<String, dynamic>? ?? {};
        fetchedCoins = vc['CO'] as int? ?? 0;

        if (foundLeague != null) {
          final ticketItemId = foundLeague['ticketItemId']?.toString() ?? '';
          final rawItems = data?['Inventory'] as List<dynamic>? ?? [];
          hasTicket = rawItems.any((item) => item['ItemId']?.toString() == ticketItemId);
        }
      }

      if (!mounted) return;
      setState(() {
        _activeLeague = foundLeague;
        _hasTicket = hasTicket;
        _coins = fetchedCoins;
        _isLoading = false;
      });

      if (foundLeague != null) {
        _startCountdown(foundLeague['leagueStartDate']?.toString() ?? '');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "שגיאת תקשורת. בדוק את החיבור לאינטרנט.";
        });
      }
    }
  }

  void _startCountdown(String leagueStartDateStr) {
    _countdownTimer?.cancel();
    if (leagueStartDateStr.isEmpty) return;

    final startDate = DateTime.tryParse(leagueStartDateStr)?.toUtc();
    if (startDate == null) return;

    void tick() {
      if (!mounted) return;
      final now = DateTime.now().toUtc();
      final diff = startDate.difference(now);
      setState(() {
        if (diff.isNegative) {
          _timeUntilStart = Duration.zero;
          _leagueStarted = true;
          _countdownTimer?.cancel();
        } else {
          _timeUntilStart = diff;
          _leagueStarted = false;
        }
      });
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _purchaseTicket() async {
    final league = _activeLeague;
    if (league == null) return;

    final itemId = league['ticketItemId']?.toString() ?? '';
    final price = (league['price'] as num?)?.toInt() ?? 0;

    if (_coins < price) {
      _showSnack("אין לך מספיק מטבעות לרכישה.", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/PurchaseItem'),
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': widget.sessionTicket,
        },
        body: json.encode({
          "CatalogVersion": "Main",
          "ItemId": itemId,
          "VirtualCurrency": "CO",
          "Price": price,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() {
          _coins -= price;
          _hasTicket = true;
          _isLoading = false;
        });
        _showSnack("הכרטיס נרכש בהצלחה! נרשמת לליגה 🎉", Colors.green);
      } else {
        setState(() => _isLoading = false);
        final errorData = json.decode(res.body);
        final errorMsg = errorData['errorMessage']?.toString() ?? '';
        final errorType = errorData['error']?.toString() ?? '';

        if (errorMsg.contains('InsufficientFunds') || errorMsg.contains('insufficient')) {
          _showSnack("אין לך מספיק מטבעות לרכישה.", Colors.redAccent);
        } else if (errorMsg.contains('already') || errorMsg.contains('owned') || errorType == 'ItemAlreadyOwned') {
          setState(() => _hasTicket = true);
          _showSnack("כבר יש לך כרטיס לליגה הזו!", Colors.orange);
        } else {
          _showSnack("שגיאת שרת: $errorType - $errorMsg", Colors.redAccent);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack("שגיאת תקשורת.", Colors.redAccent);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.right),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatCountdown(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (days > 0) return "$days ימים, $hours שעות, $minutes דקות, $seconds שניות";
    if (hours > 0) return "$hours שעות, $minutes דקות, $seconds שניות";
    if (minutes > 0) return "$minutes דקות, $seconds שניות";
    return "$seconds שניות";
  }

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
              errorBuilder: (context, error, stack) =>
                  Container(color: const Color(0xFF0A192F)),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
          const SizedBox(width: 8),
          const Text(
            "ליגות",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Spacer(),
          Row(children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
            const SizedBox(width: 4),
            Text(
              "$_coins",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
            onPressed: _loadData,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text("טוען ליגות...", style: TextStyle(color: Colors.white70, fontSize: 18)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text("נסה שוב", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (_activeLeague == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, color: Colors.white24, size: 80),
            SizedBox(height: 20),
            Text(
              "אין ליגות פעילות כרגע",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "בדוק שוב מאוחר יותר",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (isWide) {
          return Row(
            children: [
              Expanded(child: _buildInfoPanel()),
              Expanded(child: _buildLeagueCard()),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildLeagueCard(),
              _buildInfoPanel(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "מה זה ליגת בש?",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 16),
          _infoItem(Icons.emoji_events, "תחרות מרובת שחקנים",
              "התמודד מול שחקנים אחרים בטורניר מסודר עם פרסים מובטחים."),
          const SizedBox(height: 12),
          _infoItem(Icons.confirmation_number, "כרטיס כניסה",
              "כדי להצטרף לליגה תצטרך לרכוש כרטיס כניסה במטבעות שלך."),
          const SizedBox(height: 12),
          _infoItem(Icons.leaderboard, "טבלת דירוג",
              "כל ניצחון מוסיף נקודות. בסיום הליגה, המקומות הגבוהים זוכים בפרסים!"),
          const SizedBox(height: 12),
          _infoItem(Icons.timer, "ספירה לאחור",
              "הליגה תתחיל בתאריך קבוע. הצטרף לפני שהכרטיסים אוזלים."),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.amber, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(desc,
                  style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeagueCard() {
    final league = _activeLeague!;
    final name = league['name']?.toString() ?? 'ליגה';
    final current = (league['currentParticipants'] as num?)?.toInt() ?? 0;
    final max = (league['maxParticipants'] as num?)?.toInt() ?? 0;
    final price = (league['price'] as num?)?.toInt() ?? 0;
    final fillRatio = max > 0 ? current / max : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2A4A), Color(0xFF0D1B2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.withValues(alpha: 0.3), Colors.orange.withValues(alpha: 0.1)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
              ),
              const SizedBox(height: 16),

              // League name
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),

              // Participants
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("משתתפים",
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                      Text(
                        "$current / $max",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fillRatio.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fillRatio >= 0.9 ? Colors.redAccent : Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Countdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Text(
                      _leagueStarted ? "הליגה החלה!" : "מתחיל בעוד:",
                      style: TextStyle(
                        color: _leagueStarted ? Colors.greenAccent : Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _leagueStarted
                          ? "🏆 בהצלחה!"
                          : _formatCountdown(_timeUntilStart),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _leagueStarted ? Colors.greenAccent : Colors.amber,
                        fontSize: _leagueStarted ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action button
              _buildActionButton(price),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(int price) {
    if (_hasTicket) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _leagueStarted ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: _leagueStarted ? 4 : 0,
          ),
          onPressed: _leagueStarted
              ? () {
                  // TODO: navigate to league game
                  _showSnack("הליגה מתחילה! 🚀", Colors.green);
                }
              : null,
          icon: Icon(
            _leagueStarted ? Icons.play_arrow_rounded : Icons.check_circle,
            size: 22,
          ),
          label: Text(
            _leagueStarted ? "כנס לליגה!" : "נרשמת לליגה בהצלחה!",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59F00),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 4,
        ),
        onPressed: _purchaseTicket,
        icon: const Icon(Icons.confirmation_number, size: 22),
        label: Text(
          "קנה כרטיס ($price מטבעות)",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

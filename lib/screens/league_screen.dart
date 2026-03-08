import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:besh_league/screens/store_screen.dart';

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
  bool _isActioning = false;

  Map<String, dynamic>? _activeLeague;
  bool _hasTicket = false;
  String? _ticketInstanceId;
  bool _isRegistered = false;
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
        http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/GetUserData'),
          headers: headers,
          body: json.encode({"Keys": ["LeagueRegistration"]}),
        ),
      ]);

      final titleRes = results[0];
      final inventoryRes = results[1];
      final userDataRes = results[2];

      // Parse leagues — show 7 days before leagueStartDate
      Map<String, dynamic>? foundLeague;
      if (titleRes.statusCode == 200) {
        final raw = json.decode(titleRes.body)['data']?['Data']?['ActiveLeagues'];
        debugPrint("ActiveLeagues raw: $raw");
        if (raw != null && raw.toString().isNotEmpty) {
          final List<dynamic> leagues = json.decode(raw.toString());
          debugPrint("Leagues count: ${leagues.length}");
          final now = DateTime.now().toUtc();

          for (final league in leagues) {
            final leagueStartStr = league['leagueStartDate']?.toString() ?? '';
            final saleDateStr = league['saleStartDate']?.toString() ?? '';
            debugPrint("League: ${league['name']} | leagueStart: $leagueStartStr | saleStart: $saleDateStr");

            DateTime? visibilityDate;

            // Use saleStartDate if explicitly set
            if (saleDateStr.isNotEmpty) {
              visibilityDate = DateTime.tryParse(saleDateStr)?.toUtc();
            }
            // Fallback: leagueStartDate - 7 days
            if (visibilityDate == null && leagueStartStr.isNotEmpty) {
              final leagueStart = DateTime.tryParse(leagueStartStr)?.toUtc();
              if (leagueStart != null) {
                visibilityDate = leagueStart.subtract(const Duration(days: 7));
              }
            }

            // No date at all → always show
            if (visibilityDate == null || !now.isBefore(visibilityDate)) {
              foundLeague = Map<String, dynamic>.from(league);
              break;
            }
          }
        }
      }

      // Parse inventory + coins
      bool hasTicket = false;
      String? ticketInstanceId;
      int fetchedCoins = 0;
      if (inventoryRes.statusCode == 200) {
        final data = json.decode(inventoryRes.body)['data'];
        final vc = data?['VirtualCurrency'] as Map<String, dynamic>? ?? {};
        fetchedCoins = vc['CO'] as int? ?? 0;

        if (foundLeague != null) {
          final ticketItemId = foundLeague['ticketItemId']?.toString() ?? '';
          final rawItems = data?['Inventory'] as List<dynamic>? ?? [];
          for (final item in rawItems) {
            if (item['ItemId']?.toString() == ticketItemId) {
              hasTicket = true;
              ticketInstanceId = item['ItemInstanceId']?.toString();
              break;
            }
          }
        }
      }

      // Parse registration status
      bool isRegistered = false;
      if (userDataRes.statusCode == 200 && foundLeague != null) {
        final userData = json.decode(userDataRes.body)['data']?['Data'];
        final regRaw = userData?['LeagueRegistration']?['Value'];
        if (regRaw != null) {
          try {
            final reg = json.decode(regRaw.toString());
            if (reg['leagueId']?.toString() == foundLeague['leagueId']?.toString() &&
                reg['registered'] == true) {
              isRegistered = true;
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _activeLeague = foundLeague;
        _hasTicket = hasTicket;
        _ticketInstanceId = ticketInstanceId;
        _isRegistered = isRegistered;
        _coins = fetchedCoins;
        _isLoading = false;
      });

      if (foundLeague != null) {
        _startCountdown(foundLeague['leagueStartDate']?.toString() ?? '');
      }
    } catch (e) {
      debugPrint("League load error: $e");
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
      final diff = startDate.difference(DateTime.now().toUtc());
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
    if (league == null || _isActioning) return;

    final itemId = league['ticketItemId']?.toString() ?? '';
    final price = (league['price'] as num?)?.toInt() ?? 0;

    if (_coins < price) {
      _showSnack("אין לך מספיק מטבעות לרכישה.", Colors.redAccent);
      return;
    }

    setState(() => _isActioning = true);

    try {
      final res = await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/PurchaseItem'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "CatalogVersion": "Main",
          "ItemId": itemId,
          "VirtualCurrency": "CO",
          "Price": price,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        // Reload to get ItemInstanceId
        await _loadData();
        _showSnack("הכרטיס נרכש! עכשיו לחץ הירשם כדי להצטרף לליגה 🎉", Colors.green);
      } else {
        setState(() => _isActioning = false);
        final err = json.decode(res.body);
        final msg = err['errorMessage']?.toString() ?? '';
        final type = err['error']?.toString() ?? '';
        if (msg.contains('InsufficientFunds') || msg.contains('insufficient')) {
          _showSnack("אין לך מספיק מטבעות.", Colors.redAccent);
        } else if (msg.contains('already') || msg.contains('owned') || type == 'ItemAlreadyOwned') {
          await _loadData();
          _showSnack("כבר יש לך כרטיס לליגה הזו!", Colors.orange);
        } else {
          _showSnack("שגיאת רכישה: $type - $msg", Colors.redAccent);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActioning = false);
        _showSnack("שגיאת תקשורת.", Colors.redAccent);
      }
    }
  }

  Future<void> _registerForLeague() async {
    final league = _activeLeague;
    if (league == null || _isActioning || !_hasTicket) return;
    if (_ticketInstanceId == null) {
      _showSnack("שגיאה: לא נמצא מזהה כרטיס. נסה לרענן.", Colors.redAccent);
      return;
    }

    setState(() => _isActioning = true);

    try {
      // 1. Consume the ticket from inventory
      final consumeRes = await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/ConsumeItem'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "ItemInstanceId": _ticketInstanceId,
          "ConsumeCount": 1,
        }),
      );

      if (!mounted) return;

      if (consumeRes.statusCode != 200) {
        setState(() => _isActioning = false);
        final err = json.decode(consumeRes.body);
        _showSnack("שגיאה: ${err['errorMessage'] ?? 'לא ניתן לצרוך כרטיס'}", Colors.redAccent);
        return;
      }

      // 2. Increment participants + save registration via CloudScript
      await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/ExecuteCloudScript'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "FunctionName": "RegisterForLeague",
          "FunctionParameter": {"leagueId": league['leagueId']?.toString()},
        }),
      );

      // 3. Save registration locally in UserData as backup
      await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/UpdateUserData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "Data": {
            "LeagueRegistration": json.encode({
              "leagueId": league['leagueId']?.toString(),
              "registered": true,
            })
          }
        }),
      );

      if (!mounted) return;

      // Update local state — increment participant count
      final current = (league['currentParticipants'] as num?)?.toInt() ?? 0;
      setState(() {
        _hasTicket = false;
        _ticketInstanceId = null;
        _isRegistered = true;
        _isActioning = false;
        _activeLeague = {...league, 'currentParticipants': current + 1};
      });

      _showSnack("נרשמת לליגה בהצלחה! 🏆", Colors.green);
    } catch (e) {
      if (mounted) {
        setState(() => _isActioning = false);
        _showSnack("שגיאת תקשורת.", Colors.redAccent);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.right),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
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
              errorBuilder: (c, e, s) => Container(color: const Color(0xFF0A192F)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      _buildLeftSidebar(constraints.maxHeight),
                      Expanded(child: _buildMainContent()),
                      _buildRightInfoPanel(constraints.maxHeight),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LEFT SIDEBAR ──────────────────────────────────────────────────────────

  Widget _buildLeftSidebar(double height) {
    final btnSize = (height * 0.11).clamp(52.0, 80.0);
    return Container(
      width: btnSize + 20,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          const Text(
            "ליגות",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Home button
          _sideBtn(Icons.home, Colors.blueGrey, btnSize, () => Navigator.pop(context)),
          SizedBox(height: height * 0.025),
          // Store button
          _sideBtn(Icons.storefront, const Color(0xFF6AE070), btnSize, () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StoreScreen(sessionTicket: widget.sessionTicket),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sideBtn(IconData icon, Color color, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Icon(icon, size: size * 0.5, color: Colors.black),
      ),
    );
  }

  // ─── MAIN CONTENT ──────────────────────────────────────────────────────────

  Widget _buildMainContent() {
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
            Text(_errorMessage!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
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
      return _buildLockedState();
    }

    return _buildLeagueCard();
  }

  Widget _buildLockedState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12, width: 2),
            ),
            child: const Icon(Icons.lock, color: Colors.white24, size: 80),
          ),
          const SizedBox(height: 20),
          const Text(
            "אין ליגות פעילות כרגע",
            style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("בדוק שוב בקרוב", style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 20),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.white38, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueCard() {
    final league = _activeLeague!;
    final name = league['name']?.toString() ?? 'ליגה';
    final current = (league['currentParticipants'] as num?)?.toInt() ?? 0;
    final max = (league['maxParticipants'] as num?)?.toInt() ?? 0;
    final price = (league['price'] as num?)?.toInt() ?? 0;

    final ticketOwned = _hasTicket || _isRegistered;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2A4A), Color(0xFF0D1B2A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // League name
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),

                // Trophy
                const Icon(Icons.emoji_events, color: Colors.amber, size: 56),
                const SizedBox(height: 16),

                // Participants
                Text(
                  "משתתפים - $current",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: max > 0 ? (current / max).clamp(0.0, 1.0) : 0,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      current >= max ? Colors.redAccent : Colors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Countdown
                _buildCountdown(),
                const SizedBox(height: 18),

                // Register / Buy button
                _buildActionButton(price),
                const SizedBox(height: 8),

                // Ticket indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      size: 14,
                      color: ticketOwned ? Colors.amber : Colors.white30,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "כרטיסים ${ticketOwned ? 1 : 0}/1",
                      style: TextStyle(
                        color: ticketOwned ? Colors.amber : Colors.white30,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    if (_leagueStarted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
        ),
        child: const Text(
          "הליגה החלה! 🏆",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    final days = _timeUntilStart.inDays;
    final hours = _timeUntilStart.inHours.remainder(24);
    final minutes = _timeUntilStart.inMinutes.remainder(60);
    final seconds = _timeUntilStart.inSeconds.remainder(60);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text("מתחיל בעוד:", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _countUnit(days, "ימים"),
              _sep(),
              _countUnit(hours, "שעות"),
              _sep(),
              _countUnit(minutes, "דקות"),
              _sep(),
              _countUnit(seconds, "שניות"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countUnit(int value, String label) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _sep() =>
      const Text(":", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold));

  Widget _buildActionButton(int price) {
    // Already registered
    if (_isRegistered) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _leagueStarted ? Colors.green : Colors.green.withValues(alpha: 0.55),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
          ),
          onPressed: _leagueStarted
              ? () => _showSnack("הליגה מתחילה! 🚀", Colors.green)
              : null,
          icon: Icon(_leagueStarted ? Icons.play_arrow_rounded : Icons.check_circle, size: 22),
          label: Text(
            _leagueStarted ? "כנס לליגה!" : "הירשם",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // Has ticket — register (consume)
    if (_hasTicket) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28559A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
          ),
          onPressed: _isActioning ? null : _registerForLeague,
          icon: _isActioning
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.how_to_reg, size: 22),
          label: const Text("הירשם", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      );
    }

    // No ticket — buy
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59F00),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        ),
        onPressed: _isActioning ? null : _purchaseTicket,
        icon: _isActioning
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Icon(Icons.confirmation_number, size: 22),
        label: Text(
          "קנה כרטיס ($price מטבעות)",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ─── RIGHT INFO PANEL ──────────────────────────────────────────────────────

  Widget _buildRightInfoPanel(double height) {
    return Container(
      width: (height * 0.3).clamp(160.0, 240.0),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Text(
              "מידע על הליגה",
              style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const Expanded(
            child: _InfoPageView(),
          ),
        ],
      ),
    );
  }
}

// ─── INFO PAGE VIEW ─────────────────────────────────────────────────────────

class _InfoPageView extends StatefulWidget {
  const _InfoPageView();

  @override
  State<_InfoPageView> createState() => _InfoPageViewState();
}

class _InfoPageViewState extends State<_InfoPageView> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _InfoData(Icons.emoji_events, "ליגת בש", "תחרות מרובת שחקנים עם פרסים ממשיים לזוכים. כל חודש ליגה חדשה!"),
    _InfoData(Icons.confirmation_number, "כרטיס כניסה", "רכוש כרטיס כניסה, לחץ הירשם. הכרטיס ייצרך ותירשם לליגה אוטומטית."),
    _InfoData(Icons.leaderboard, "טבלת דירוג", "כל ניצחון מוסיף נקודות לדירוג. בסיום הליגה הזוכים מקבלים פרסים אמיתיים!"),
    _InfoData(Icons.timer, "ספירה לאחור", "הליגה תתחיל בתאריך קבוע. הצטרף לפני שהכרטיסים אוזלים."),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final p = _pages[i];
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(p.icon, color: Colors.amber, size: 32),
                    const SizedBox(height: 10),
                    Text(p.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(p.body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.5)),
                  ],
                ),
              );
            },
          ),
        ),
        // Page dots
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? Colors.amber : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoData {
  final IconData icon;
  final String title;
  final String body;
  const _InfoData(this.icon, this.title, this.body);
}

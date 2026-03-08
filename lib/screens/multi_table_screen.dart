import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'game_board_screen.dart';
import '../services/bot_service.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class MatchPair {
  final String player1Id;
  final String player1Name;
  final int player1Trophies;
  final String player2Id;
  final String player2Name;
  final int player2Trophies;
  final String roomId;
  final BotSkill? botSkill;

  const MatchPair({
    required this.player1Id,
    required this.player1Name,
    required this.player1Trophies,
    required this.player2Id,
    required this.player2Name,
    required this.player2Trophies,
    required this.roomId,
    this.botSkill,
  });
}

enum TableStatus { waiting, playing, finished }

// ─── Screen ───────────────────────────────────────────────────────────────────

class MultiTableScreen extends StatefulWidget {
  final String sessionTicket;
  final String myPlayFabId;
  final String myName;
  final int myTrophies;
  /// Pass an explicit list of pairs, OR leave empty + set loadFromServer=true
  /// to automatically fetch all active tables from PlayFab TitleData (ActiveRooms).
  final List<MatchPair> pairs;
  final bool loadFromServer;
  final int betAmount;
  final String tournamentTitle;

  const MultiTableScreen({
    super.key,
    this.sessionTicket = "",
    required this.myPlayFabId,
    required this.myName,
    required this.myTrophies,
    this.pairs = const [],
    this.loadFromServer = false,
    this.betAmount = 0,
    this.tournamentTitle = "שולחנות פעילים",
  });

  @override
  State<MultiTableScreen> createState() => _MultiTableScreenState();
}

class _MultiTableScreenState extends State<MultiTableScreen> {
  static const String _titleId = "1A15A2";

  List<MatchPair> _pairs = [];
  final Map<String, TableStatus> _tableStatuses = {};
  final Map<String, String> _tableWinners = {};
  Timer? _pollTimer;

  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.loadFromServer) {
      _fetchActiveRooms();
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchActiveRooms());
    } else {
      _pairs = List.from(widget.pairs);
      for (final pair in _pairs) {
        _tableStatuses[pair.roomId] = TableStatus.waiting;
      }
      if (widget.sessionTicket.isNotEmpty) {
        _pollAllStatuses();
        _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollAllStatuses());
      }
    }
  }

  // ─── Fetch all active rooms from TitleData["ActiveRooms"] ─────────────────
  Future<void> _fetchActiveRooms() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final res = await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/GetTitleData'),
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': widget.sessionTicket,
        },
        body: json.encode({"Keys": ["ActiveRooms"]}),
      );
      if (!mounted) return;
      final body = json.decode(res.body);
      final dataMap = body['data']?['Data'] as Map<String, dynamic>?;
      final rawJson = dataMap?['ActiveRooms'] ?? '[]';
      final List<dynamic> roomsJson = json.decode(rawJson);

      final loaded = <MatchPair>[];
      for (final r in roomsJson) {
        final pair = MatchPair(
          player1Id: r['player1Id'] ?? '',
          player1Name: r['player1Name'] ?? 'שחקן',
          player1Trophies: (r['player1Trophies'] as num?)?.toInt() ?? 0,
          player2Id: r['player2Id'] ?? '',
          player2Name: r['player2Name'] ?? 'שחקן',
          player2Trophies: (r['player2Trophies'] as num?)?.toInt() ?? 0,
          roomId: r['roomId'] ?? '',
        );
        loaded.add(pair);
        // Seed status from server-stored value if available
        final statusStr = r['status'] ?? '';
        final winnerName = r['winnerName'] ?? '';
        TableStatus ts = TableStatus.waiting;
        if (statusStr == 'playing') {
          ts = TableStatus.playing;
        } else if (statusStr == 'finished') {
          ts = TableStatus.finished;
        }
        _tableStatuses[pair.roomId] = ts;
        if (winnerName.isNotEmpty) _tableWinners[pair.roomId] = winnerName;
      }

      setState(() {
        _pairs = loaded;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = "שגיאה בטעינת השולחנות";
        });
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollAllStatuses() async {
    for (final pair in _pairs) {
      if (pair.roomId.isEmpty) continue;
      _pollTableStatus(pair);
    }
  }

  Future<void> _pollTableStatus(MatchPair pair) async {
    if (!mounted) return;
    try {
      final res = await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/GetSharedGroupData'),
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': widget.sessionTicket,
        },
        body: json.encode({
          "SharedGroupId": pair.roomId,
          "Keys": ["game_status", "winner_name"],
        }),
      );
      if (!mounted) return;
      final data = json.decode(res.body)['data']?['Data'];
      if (data == null) return;
      final statusStr = data['game_status']?['Value'] ?? '';
      final winnerName = data['winner_name']?['Value'] ?? '';
      TableStatus ts = TableStatus.waiting;
      if (statusStr == 'playing') {
        ts = TableStatus.playing;
      } else if (statusStr == 'finished') {
        ts = TableStatus.finished;
      }
      setState(() {
        _tableStatuses[pair.roomId] = ts;
        if (winnerName.isNotEmpty) _tableWinners[pair.roomId] = winnerName;
      });
    } catch (_) {}
  }

  bool _isMyPair(MatchPair pair) =>
      pair.player1Id == widget.myPlayFabId ||
      pair.player2Id == widget.myPlayFabId;

  String _opponentId(MatchPair pair) =>
      pair.player1Id == widget.myPlayFabId ? pair.player2Id : pair.player1Id;

  String _opponentName(MatchPair pair) =>
      pair.player1Id == widget.myPlayFabId ? pair.player2Name : pair.player1Name;

  int _opponentTrophies(MatchPair pair) =>
      pair.player1Id == widget.myPlayFabId
          ? pair.player2Trophies
          : pair.player1Trophies;

  Future<void> _enterGame(MatchPair pair) async {
    setState(() => _tableStatuses[pair.roomId] = TableStatus.playing);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameBoardScreen(
          sessionTicket: widget.sessionTicket,
          roomId: pair.roomId,
          myPlayFabId: widget.myPlayFabId,
          myName: widget.myName,
          myTrophies: widget.myTrophies,
          opponentId: _opponentId(pair),
          opponentName: _opponentName(pair),
          opponentTrophies: _opponentTrophies(pair),
          betAmount: widget.betAmount,
          botSkill: pair.botSkill,
        ),
      ),
    );
    if (mounted) {
      setState(() => _tableStatuses[pair.roomId] = TableStatus.finished);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

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
            Container(color: Colors.black.withValues(alpha: 0.45)),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  if (!_isLoading && _loadError == null) _buildStats(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            child: Text(
              widget.tournamentTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_chart, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  "${_pairs.length} שולחנות",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (widget.loadFromServer) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isLoading ? null : _fetchActiveRooms,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white60),
                      )
                    : const Icon(Icons.refresh, color: Colors.white70, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    final playing = _tableStatuses.values.where((s) => s == TableStatus.playing).length;
    final finished = _tableStatuses.values.where((s) => s == TableStatus.finished).length;
    final waiting = _tableStatuses.values.where((s) => s == TableStatus.waiting).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildStatChip(Icons.hourglass_empty, "$waiting ממתינים", Colors.orange),
          const SizedBox(width: 8),
          _buildStatChip(Icons.sports_esports, "$playing משחקים", Colors.greenAccent),
          const SizedBox(width: 8),
          _buildStatChip(Icons.check_circle, "$finished סיימו", Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
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
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 16),
            Text("טוען שולחנות...", style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_loadError!, style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchActiveRooms,
              icon: const Icon(Icons.refresh),
              label: const Text("נסה שוב"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F)),
            ),
          ],
        ),
      );
    }
    if (_pairs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_chart, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text("אין שולחנות פעילים כרגע", style: TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 8),
            const Text("בדוק שוב בקרוב", style: TextStyle(color: Colors.white38, fontSize: 14)),
            if (widget.loadFromServer) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchActiveRooms,
                icon: const Icon(Icons.refresh),
                label: const Text("רענן"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F)),
              ),
            ],
          ],
        ),
      );
    }
    return _buildTableList();
  }

  Widget _buildTableList() {
    // Sort: my table first, then others
    final sorted = [..._pairs];
    sorted.sort((a, b) => _isMyPair(a) ? -1 : (_isMyPair(b) ? 1 : 0));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final pair = sorted[index];
        final tableNumber = _pairs.indexOf(pair) + 1;
        final isMyTable = _isMyPair(pair);
        final status = _tableStatuses[pair.roomId] ?? TableStatus.waiting;
        final winner = _tableWinners[pair.roomId];
        return _buildTableCard(
          pair: pair,
          tableNumber: tableNumber,
          isMyTable: isMyTable,
          status: status,
          winner: winner,
        );
      },
    );
  }

  Widget _buildTableCard({
    required MatchPair pair,
    required int tableNumber,
    required bool isMyTable,
    required TableStatus status,
    String? winner,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isMyTable
              ? [const Color(0xFF2A1F00), const Color(0xFF1A1200)]
              : [const Color(0xFF1A2535), const Color(0xFF0F1820)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMyTable ? const Color(0xFFFFD700) : Colors.white12,
          width: isMyTable ? 2.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isMyTable
                ? const Color(0xFFFFD700).withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Card header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                _buildTableLabel(tableNumber, isMyTable),
                const SizedBox(width: 8),
                if (isMyTable) _buildMyTableBadge(),
                const Spacer(),
                _buildStatusBadge(status),
              ],
            ),
          ),
          // ── Players ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildPlayerChip(
                    pair.player1Name,
                    pair.player1Trophies,
                    pair.player1Id == widget.myPlayFabId,
                    Alignment.centerRight,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "VS",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      if (widget.betAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              "${widget.betAmount}",
                              style: const TextStyle(color: Colors.amber, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _buildPlayerChip(
                    pair.player2Name,
                    pair.player2Trophies,
                    pair.player2Id == widget.myPlayFabId,
                    Alignment.centerLeft,
                  ),
                ),
              ],
            ),
          ),
          // ── Action / Result row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: status == TableStatus.finished
                ? _buildFinishedRow(winner)
                : isMyTable
                    ? _buildEnterButton(pair, status)
                    : _buildSpectateButton(status),
          ),
        ],
      ),
    );
  }

  Widget _buildTableLabel(int number, bool isMyTable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMyTable
            ? const Color(0xFFFFD700).withValues(alpha: 0.15)
            : Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "שולחן $number",
        style: TextStyle(
          color: isMyTable ? const Color(0xFFFFD700) : Colors.white60,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMyTableBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
          SizedBox(width: 4),
          Text(
            "השולחן שלי",
            style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TableStatus status) {
    late final String label;
    late final Color color;
    late final IconData icon;
    switch (status) {
      case TableStatus.waiting:
        label = "ממתין";
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case TableStatus.playing:
        label = "משחק";
        color = Colors.greenAccent;
        icon = Icons.sports_esports;
        break;
      case TableStatus.finished:
        label = "סיים";
        color = Colors.blueAccent;
        icon = Icons.check_circle;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerChip(String name, int trophies, bool isMe, Alignment align) {
    return Column(
      crossAxisAlignment: align == Alignment.centerRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: align,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF1A3A5F) : Colors.white10,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isMe ? Colors.blueAccent : Colors.white24,
                width: isMe ? 2 : 1,
              ),
            ),
            child: Icon(
              Icons.person,
              color: isMe ? Colors.blueAccent : Colors.white54,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 12),
            const SizedBox(width: 3),
            Text("$trophies", style: const TextStyle(color: Colors.amber, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildEnterButton(MatchPair pair, TableStatus status) {
    final isPlaying = status == TableStatus.playing;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: () => _enterGame(pair),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPlaying ? const Color(0xFF1A6B30) : const Color(0xFFB8860B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          isPlaying ? "חזור למשחק" : "כנס למשחק",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSpectateButton(TableStatus status) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white38,
          disabledForegroundColor: Colors.white38,
          side: const BorderSide(color: Colors.white12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility, size: 16),
            const SizedBox(width: 6),
            Text(
              status == TableStatus.playing ? "צפה" : "ממתין להתחלה",
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedRow(String? winner) {
    return Container(
      width: double.infinity,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Text(
            winner != null ? "ניצח: $winner" : "המשחק הסתיים",
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DailyStreakScreen extends StatefulWidget {
  final String sessionTicket;

  const DailyStreakScreen({super.key, required this.sessionTicket});

  @override
  State<DailyStreakScreen> createState() => _DailyStreakScreenState();
}

class _DailyStreakScreenState extends State<DailyStreakScreen> {
  bool isLoading = true;
  bool isClaiming = false;
  int streakDays = 0;
  bool canClaim = false;
  bool alreadyClaimed = false;

  @override
  void initState() {
    super.initState();
    _loadStreakData();
  }

  int _rewardForDay(int day) {
    if (day >= 4) return 200;
    switch (day) {
      case 1: return 50;
      case 2: return 100;
      case 3: return 150;
      default: return 200;
    }
  }

  Future<void> _loadStreakData() async {
    const titleId = "1A15A2";
    try {
      final res = await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/GetUserData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"Keys": ["StreakDays", "LastStreakClaim"]}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data']?['Data'];
        if (data != null) {
          final savedStreak = int.tryParse(data['StreakDays']?['Value'] ?? '0') ?? 0;
          final lastClaimStr = data['LastStreakClaim']?['Value'] ?? '';

          bool canClaimNow = false;
          int currentStreak = savedStreak;

          if (lastClaimStr.isEmpty) {
            canClaimNow = true;
            currentStreak = 0;
          } else {
            final lastClaim = DateTime.tryParse(lastClaimStr);
            if (lastClaim != null) {
              final now = DateTime.now().toUtc();
              final diff = now.difference(lastClaim);
              if (diff.inHours < 24) {
                canClaimNow = false;
              } else if (diff.inHours < 48) {
                canClaimNow = true;
              } else {
                canClaimNow = true;
                currentStreak = 0;
              }
            } else {
              canClaimNow = true;
              currentStreak = 0;
            }
          }

          if (mounted) {
            setState(() {
              streakDays = currentStreak;
              canClaim = canClaimNow;
              alreadyClaimed = !canClaimNow;
              isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() { canClaim = true; isLoading = false; });
        }
      } else {
        if (mounted) setState(() { isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; });
    }
  }

  Future<void> _claimReward() async {
    if (!canClaim || isClaiming) return;
    setState(() { isClaiming = true; });

    const titleId = "1A15A2";
    final newStreak = streakDays + 1;
    final reward = _rewardForDay(newStreak);

    try {
      await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/AddUserVirtualCurrency'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({"VirtualCurrency": "CO", "Amount": reward}),
      );

      await http.post(
        Uri.parse('https://$titleId.playfabapi.com/Client/UpdateUserData'),
        headers: {'Content-Type': 'application/json', 'X-Authorization': widget.sessionTicket},
        body: json.encode({
          "Data": {
            "StreakDays": newStreak.toString(),
            "LastStreakClaim": DateTime.now().toUtc().toIso8601String(),
          }
        }),
      );

      if (mounted) {
        setState(() {
          streakDays = newStreak;
          canClaim = false;
          alreadyClaimed = true;
          isClaiming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("קיבלת $reward מטבעות!", textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() { isClaiming = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A192F), Color(0xFF1A3A5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          "כניסה יומית",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                if (isLoading)
                  const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.amber)))
                else
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 60),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber, width: 2),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orange, size: 56),
                              const SizedBox(height: 8),
                              Text(
                                "$streakDays",
                                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const Text(
                                "ימי רצף",
                                style: TextStyle(fontSize: 20, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDayReward(1, 50),
                              _buildDayReward(2, 100),
                              _buildDayReward(3, 150),
                              _buildDayReward(4, 200, isPlus: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 44),
                        GestureDetector(
                          onTap: canClaim ? _claimReward : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: canClaim
                                    ? [const Color(0xFFFFB300), const Color(0xFFFF6F00)]
                                    : [Colors.grey.shade700, Colors.grey.shade800],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: canClaim ? Colors.amber : Colors.grey, width: 2),
                            ),
                            child: isClaiming
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  )
                                : Text(
                                    alreadyClaimed ? "כבר קיבלת היום" : "קבל פרס!",
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
                        ),
                        if (alreadyClaimed)
                          const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: Text(
                              "חזור מחר לפרס הבא",
                              style: TextStyle(fontSize: 16, color: Colors.white54),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayReward(int day, int coins, {bool isPlus = false}) {
    final isCompleted = streakDays >= day;
    final isNext = (day == streakDays + 1) && canClaim;
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.amber.withValues(alpha: 0.25)
            : isNext
                ? Colors.blue.withValues(alpha: 0.25)
                : Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.amber : (isNext ? Colors.lightBlueAccent : Colors.white24),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isPlus ? "יום 4+" : "יום $day",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isCompleted ? Colors.amber : Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Icon(
            isCompleted ? Icons.check_circle : Icons.monetization_on,
            color: isCompleted ? Colors.amber : Colors.white54,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            "$coins",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCompleted ? Colors.amber : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

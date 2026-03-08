import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InventoryScreen extends StatefulWidget {
  final String sessionTicket;

  const InventoryScreen({super.key, required this.sessionTicket});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _titleId = "1A15A2";

  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final res = await http.post(
        Uri.parse('https://$_titleId.playfabapi.com/Client/GetUserInventory'),
        headers: {
          'Content-Type': 'application/json',
          'X-Authorization': widget.sessionTicket,
        },
        body: '{}',
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        final vc = data?['VirtualCurrency'] as Map<String, dynamic>? ?? {};
        final rawItems = data?['Inventory'] as List<dynamic>? ?? [];

        final items = rawItems.map<Map<String, dynamic>>((item) => {
          'ItemId': item['ItemId']?.toString() ?? '',
          'ItemInstanceId': item['ItemInstanceId']?.toString() ?? '',
          'DisplayName': item['DisplayName']?.toString() ?? item['ItemId']?.toString() ?? 'פריט',
          'RemainingUses': item['RemainingUses'],
        }).toList();

        setState(() {
          _coins = vc['CO'] as int? ?? 0;
          _inventoryItems = items;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "שגיאה בטעינת המלאי.";
        });
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
              errorBuilder: (context, error, stack) => Container(color: const Color(0xFF0A192F)),
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
          const Icon(Icons.inventory_2, color: Colors.amber, size: 28),
          const SizedBox(width: 8),
          const Text("המלאי שלי", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          Row(children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
            const SizedBox(width: 4),
            Text("$_coins", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
            onPressed: _loadInventory,
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
            Text("טוען מלאי...", style: TextStyle(color: Colors.white70, fontSize: 18)),
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
              onPressed: _loadInventory,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text("נסה שוב", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (_inventoryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 80),
            const SizedBox(height: 20),
            const Text(
              "המלאי שלך ריק כרגע.\nגש לחנות כדי לרכוש כרטיסים!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 20, height: 1.6),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.storefront, color: Colors.black),
              label: const Text("לחנות", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 800 ? 4 : 3;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "${_inventoryItems.length} פריטים במלאי",
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _inventoryItems.length,
                  itemBuilder: (ctx, i) => _buildItemTile(_inventoryItems[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final name = item['DisplayName'] as String;
    final remaining = item['RemainingUses'];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2A4A), Color(0xFF0D1B2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.08), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number, color: Colors.amber, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (remaining != null) ...[
              const SizedBox(height: 4),
              Text(
                "נותרו: $remaining",
                style: const TextStyle(fontSize: 11, color: Colors.amber),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StoreScreen extends StatefulWidget {
  final String sessionTicket;

  const StoreScreen({super.key, required this.sessionTicket});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  static const _titleId = "1A15A2";

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _coins = 0;
  final Set<String> _purchasing = {};

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final headers = {
        'Content-Type': 'application/json',
        'X-Authorization': widget.sessionTicket,
      };

      final results = await Future.wait([
        http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/GetCatalogItems'),
          headers: headers,
          body: json.encode({"CatalogVersion": "Main"}),
        ),
        http.post(
          Uri.parse('https://$_titleId.playfabapi.com/Client/GetUserInventory'),
          headers: headers,
          body: '{}',
        ),
      ]);

      final catalogRes = results[0];
      final inventoryRes = results[1];

      List<Map<String, dynamic>> fetchedItems = [];
      if (catalogRes.statusCode == 200) {
        final data = json.decode(catalogRes.body)['data']?['Catalog'] as List<dynamic>? ?? [];
        for (final item in data) {
          final vcPrices = item['VirtualCurrencyPrices'] as Map<String, dynamic>? ?? {};
          final price = vcPrices['CO'] as int? ?? 0;
          fetchedItems.add({
            'ItemId': item['ItemId']?.toString() ?? '',
            'DisplayName': item['DisplayName']?.toString() ?? item['ItemId']?.toString() ?? 'פריט',
            'Description': item['Description']?.toString() ?? '',
            'Price': price,
          });
        }
      }

      int fetchedCoins = 0;
      if (inventoryRes.statusCode == 200) {
        final vc = json.decode(inventoryRes.body)['data']?['VirtualCurrency'];
        fetchedCoins = vc?['CO'] as int? ?? 0;
      }

      if (mounted) {
        setState(() {
          _items = fetchedItems;
          _coins = fetchedCoins;
          _isLoading = false;
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

  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    final itemId = item['ItemId'] as String;
    final price = item['Price'] as int;

    if (_coins < price) {
      _showSnack("אין לך מספיק מטבעות לרכישה.", Colors.redAccent);
      return;
    }

    setState(() { _purchasing.add(itemId); });

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
        setState(() { _coins -= price; });
        _showSnack("הפריט נוסף למלאי שלך! 🎉", Colors.green);
      } else {
        final errorData = json.decode(res.body);
        // שולף גם את ההודעה וגם את סוג השגיאה המדויק מפלייפאב
        final errorMsg = errorData['errorMessage']?.toString() ?? '';
        final errorType = errorData['error']?.toString() ?? '';

        if (errorMsg.contains('InsufficientFunds') || errorMsg.contains('insufficient')) {
          _showSnack("אין לך מספיק מטבעות לרכישה.", Colors.redAccent);
        } else if (errorMsg.contains('already') || errorMsg.contains('owned') || errorType == 'ItemAlreadyOwned') {
          _showSnack("כבר יש לך את הפריט הזה במלאי (אי אפשר לקנות פעמיים).", Colors.orange);
        } else {
          // מציג לנו על המסך את השגיאה המדויקת באנגלית כדי שנדע מה לתקן!
          _showSnack("שגיאת שרת: $errorType - $errorMsg", Colors.redAccent);
        }
      }
    } catch (e) {
      if (mounted) _showSnack("שגיאת תקשורת.", Colors.redAccent);
    } finally {
      if (mounted) setState(() { _purchasing.remove(itemId); });
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textAlign: TextAlign.right), backgroundColor: color, duration: const Duration(seconds: 3)),
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
          const Icon(Icons.storefront, color: Colors.amber, size: 28),
          const SizedBox(width: 8),
          const Text("חנות", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          Row(children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
            const SizedBox(width: 4),
            Text("$_coins", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
            onPressed: _loadCatalog,
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
            Text("טוען פריטים...", style: TextStyle(color: Colors.white70, fontSize: 18)),
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
              onPressed: _loadCatalog,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text("נסה שוב", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront, color: Colors.white24, size: 70),
            SizedBox(height: 16),
            Text("החנות ריקה כרגע.\nבדוק שוב מאוחר יותר!", textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _items.length,
      itemBuilder: (ctx, i) => _buildItemCard(_items[i]),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemId = item['ItemId'] as String;
    final name = item['DisplayName'] as String;
    final description = item['Description'] as String;
    final price = item['Price'] as int;
    final canAfford = _coins >= price;
    final isPurchasing = _purchasing.contains(itemId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canAfford
              ? [const Color(0xFF1A2A4A), const Color(0xFF0D1B2A)]
              : [const Color(0xFF1A1A1A), const Color(0xFF111111)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canAfford ? Colors.amber.withValues(alpha: 0.5) : Colors.white12,
          width: 1.5,
        ),
        boxShadow: canAfford
            ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.1), blurRadius: 8)]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Icon on the right (RTL)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number, color: Colors.amber, size: 26),
            ),
            const SizedBox(width: 12),
            // Name + description in the center
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Price + buy button on the left (RTL = left side)
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 15),
                    const SizedBox(width: 3),
                    Text(
                      "$price",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: canAfford ? Colors.amber : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 80,
                  height: 30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? const Color(0xFF28559A) : Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: (isPurchasing || !canAfford) ? null : () => _purchaseItem(item),
                    child: isPurchasing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            canAfford ? "קנה" : "אין מספיק",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

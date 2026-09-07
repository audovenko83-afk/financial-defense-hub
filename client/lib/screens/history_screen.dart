import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class HistoryScreen extends StatefulWidget {
  final String token;
  final bool isTab;

  const HistoryScreen({super.key, required this.token, this.isTab = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<dynamic>> _historyFuture;
  String _selectedFilter = 'Всі';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _historyFuture = _fetchHistory();
    });
  }

  Future<List<dynamic>> _fetchHistory() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/history'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    throw Exception('Помилка сервера (код ${res.statusCode})');
  }

  List<dynamic> _filterTransactions(List<dynamic> list) {
    if (_selectedFilter == 'Всі') return list;
    return list.where((item) {
      final type = (item['type'] ?? 'BUY').toString().toUpperCase();
      if (_selectedFilter == 'Купівля') return type == 'BUY';
      if (_selectedFilter == 'Продаж') return type == 'SELL';
      if (_selectedFilter == 'Поповнення') return type == 'DEPOSIT';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.isTab
          ? null
          : AppBar(
              title: const Text(AppStrings.transactionHistory, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildTransactionList()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Всі', 'Купівля', 'Продаж', 'Поповнення'].map((f) {
            final isSel = _selectedFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSel,
                label: Text(f, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                selectedColor: const Color(0xFF00FF94).withValues(alpha: 0.2),
                checkmarkColor: const Color(0xFF00FF94),
                backgroundColor: const Color(0xFF161B26),
                side: BorderSide(color: isSel ? const Color(0xFF00FF94) : Colors.white10),
                onSelected: (_) => setState(() => _selectedFilter = f),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return FutureBuilder<List<dynamic>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF94)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Помилка: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _refresh, child: const Text('Спробувати знову')),
              ],
            ),
          );
        }
        final list = _filterTransactions(snapshot.data ?? []);
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                const Text('Операцій ще немає', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF00FF94),
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: list.length,
            itemBuilder: (context, i) => _buildTransactionItem(list[i] as Map<String, dynamic>),
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final type = (tx['type'] ?? 'BUY').toString().toUpperCase();
    final ticker = tx['ticker'] ?? '';
    final shares = (tx['shares'] as num?)?.toDouble() ?? 0;
    final price = (tx['price'] as num?)?.toDouble() ?? 0;
    final totalAmount = (tx['total_amount'] as num?)?.toDouble() ?? (shares * price);
    final rawDate = (tx['created_at'] ?? '').toString().replaceAll('T', ' ');
    final dateStr = rawDate.length > 16 ? rawDate.substring(0, 16) : rawDate;

    Color iconColor;
    IconData icon;
    String title;
    String amountText;

    if (type == 'BUY') {
      iconColor = const Color(0xFF00FF94);
      icon = Icons.shopping_bag_outlined;
      title = 'Купівля $ticker (${shares.toStringAsFixed(4)} шт)';
      amountText = '-\$${totalAmount.toStringAsFixed(2)}';
    } else if (type == 'SELL') {
      iconColor = const Color(0xFF00E0FF);
      icon = Icons.sell_outlined;
      title = 'Продаж $ticker (${shares.toStringAsFixed(4)} шт)';
      amountText = '+\$${totalAmount.toStringAsFixed(2)}';
    } else if (type == 'DEPOSIT') {
      iconColor = const Color(0xFFFFC857);
      icon = Icons.account_balance_wallet_outlined;
      title = 'Поповнення балансу';
      amountText = '+\$${totalAmount.toStringAsFixed(2)}';
    } else {
      iconColor = Colors.orangeAccent;
      icon = Icons.money_off_rounded;
      title = 'Виведення коштів';
      amountText = '-\$${totalAmount.toStringAsFixed(2)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 3),
                Text(dateStr.isEmpty ? 'Щойно' : dateStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  color: type == 'BUY' ? Colors.white : (type == 'SELL' || type == 'DEPOSIT' ? const Color(0xFF00FF94) : Colors.orangeAccent),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              if (price > 0 && type != 'DEPOSIT') ...[
                const SizedBox(height: 2),
                Text('по \$${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

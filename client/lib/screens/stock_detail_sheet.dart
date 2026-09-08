import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/models.dart';
import '../widgets/stock_logo.dart';
import '../widgets/interactive_stock_chart.dart';
import '../widgets/info_helper_sheet.dart';

class StockDetailSheet extends StatefulWidget {
  final String token;
  final String ticker;
  final String name;
  final String sector;
  final double currentPrice;
  final String description;
  final Position? ownedPosition;
  final VoidCallback onPortfolioUpdated;

  final VoidCallback? onUnauthorized;

  const StockDetailSheet({
    super.key,
    required this.token,
    required this.ticker,
    required this.name,
    required this.sector,
    required this.currentPrice,
    required this.description,
    this.ownedPosition,
    required this.onPortfolioUpdated,
    this.onUnauthorized,
  });

  static void show(
    BuildContext context, {
    required String token,
    required String ticker,
    required String name,
    required String sector,
    required double currentPrice,
    required String description,
    Position? ownedPosition,
    required VoidCallback onPortfolioUpdated,
    VoidCallback? onUnauthorized,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StockDetailSheet(
        token: token,
        ticker: ticker,
        name: name,
        sector: sector,
        currentPrice: currentPrice,
        description: description,
        ownedPosition: ownedPosition,
        onPortfolioUpdated: onPortfolioUpdated,
        onUnauthorized: onUnauthorized,
      ),
    );
  }

  @override
  State<StockDetailSheet> createState() => _StockDetailSheetState();
}

class _StockDetailSheetState extends State<StockDetailSheet> {
  String _selectedRange = '1mo';
  List<Map<String, dynamic>> _chartPoints = [];
  bool _isLoadingHistory = false;
  double _livePrice = 0.0;
  double _dayChange = 0.0;
  double _dayChangePercent = 0.0;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _livePrice = widget.ownedPosition?.currentPrice ?? widget.currentPrice;
    _fetchLiveQuote();
    _fetchHistory(_selectedRange);
  }

  Future<void> _fetchLiveQuote() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/market/quote?ticker=${widget.ticker}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _livePrice = (data['price'] as num?)?.toDouble() ?? _livePrice;
            _dayChange = (data['change'] as num?)?.toDouble() ?? 0.0;
            _dayChangePercent = (data['change_percent'] as num?)?.toDouble() ?? 0.0;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchHistory(String range) async {
    setState(() {
      _selectedRange = range;
      _isLoadingHistory = true;
    });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/market/history?ticker=${widget.ticker}&range=$range'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawPoints = (data['points'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _chartPoints = rawPoints.map((p) => {
              'date': p['date']?.toString() ?? '',
              'close': (p['close'] as num?)?.toDouble() ?? 0.0,
            }).where((p) => (p['close'] as double) > 0).toList();
            _isLoadingHistory = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  Future<void> _buyDollarAmount(double dollars) async {
    if (dollars <= 0 || _livePrice <= 0) return;
    setState(() => _isActionInProgress = true);
    final shares = dollars / _livePrice;
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'ticker': widget.ticker,
          'asset_class': 'Stock',
          'shares': shares,
          'price': _livePrice,
        }),
      );
      if (res.statusCode == 200) {
        widget.onPortfolioUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF00FF94),
              content: Text('Успішно інвестовано \$$dollars в ${widget.ticker}!', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          );
        }
      } else {
        throw Exception(res.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _sellPosition(double sharesToSell) async {
    if (sharesToSell <= 0 || _livePrice <= 0) return;
    setState(() => _isActionInProgress = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/transactions/sell'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'ticker': widget.ticker,
          'shares': sharesToSell,
          'price': _livePrice,
        }),
      );
      if (res.statusCode == 200) {
        widget.onPortfolioUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF00E5FF),
              content: Text('Продано ${sharesToSell.toStringAsFixed(4)} шт ${widget.ticker}!', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          );
        }
      } else {
        throw Exception(res.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPos = _dayChange >= 0;
    final changeColor = isPos ? const Color(0xFF00FF94) : const Color(0xFFFF5252);
    final sign = isPos ? '+' : '';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131722),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Закрити',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                StockLogo(
                  ticker: widget.ticker,
                  size: 48,
                  borderRadius: 14,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.ticker, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                            child: Text(widget.sector, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ),
                        ],
                      ),
                      Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${_livePrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('$sign\$${_dayChange.toStringAsFixed(2)} ($sign${_dayChangePercent.toStringAsFixed(2)}%)',
                      style: TextStyle(color: changeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            InteractiveStockChart(
              points: _chartPoints.map((p) => ChartPoint(date: p['date'] as String, close: p['close'] as double)).toList(),
              selectedRange: _selectedRange,
              isLoading: _isLoadingHistory,
              currentPrice: _livePrice,
              onRangeChanged: (r) => _fetchHistory(r),
            ),
            const SizedBox(height: 14),
            _buildHoldingSection(),
            const SizedBox(height: 14),
            _buildActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingSection() {
    if (widget.ownedPosition == null) {
      if (widget.description.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1A1F2C), borderRadius: BorderRadius.circular(14)),
        child: Text(widget.description, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35)),
      );
    }
    final pos = widget.ownedPosition!;
    final isProfit = pos.unrealizedPnL >= 0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF132A24), Color(0xFF111D24)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('У ВАШОМУ ПОРТФЕЛІ', style: TextStyle(color: Color(0xFF00FF94), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      SizedBox(width: 4),
                      InfoButton(topic: InfoTopic.unrealizedPnL, size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${pos.shares.toStringAsFixed(4)} шт. • Сер.: \$${pos.averageBuyPrice.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const InfoButton(topic: InfoTopic.avgPrice, size: 13),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${pos.totalValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(
                    '${isProfit ? '+' : ''}\$${pos.unrealizedPnL.toStringAsFixed(2)} (${isProfit ? '+' : ''}${pos.unrealizedPnLPercent.toStringAsFixed(1)}%)',
                    style: TextStyle(color: isProfit ? const Color(0xFF00FF94) : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Швидке інвестування', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00FF94),
                  side: const BorderSide(color: Color(0xFF00FF94)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isActionInProgress ? null : () => _buyDollarAmount(1.0),
                child: const Text('+\$1 (План)', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isActionInProgress ? null : () => _buyDollarAmount(10.0),
                child: const Text('+\$10', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isActionInProgress ? null : () => _buyDollarAmount(50.0),
                child: const Text('+\$50', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (widget.ownedPosition != null && widget.ownedPosition!.shares > 0) ...[
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent),
                tooltip: 'Продати всі',
                onPressed: _isActionInProgress ? null : () => _sellPosition(widget.ownedPosition!.shares),
                icon: const Icon(Icons.sell_outlined, size: 20),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

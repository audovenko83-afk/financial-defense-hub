import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/models.dart';
import '../models/strategy_stocks.dart';
import '../widgets/stock_logo.dart';
import '../widgets/info_helper_sheet.dart';
import 'stock_detail_sheet.dart';

class StrategyScreen extends StatefulWidget {
  final String token;
  final PortfolioData? portfolioData;
  final VoidCallback onRefreshPortfolio;

  const StrategyScreen({
    super.key,
    required this.token,
    required this.portfolioData,
    required this.onRefreshPortfolio,
  });

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> {
  String _searchQuery = '';
  String _selectedSector = 'Всі';
  bool _isBatchInvesting = false;

  List<String> get _sectors {
    final set = {'Всі', 'В портфелі'};
    for (final s in MillionDollarPortfolio.stocks) {
      set.add(s.sector);
    }
    return set.toList();
  }

  Position? _findPosition(String ticker) {
    if (widget.portfolioData == null) return null;
    try {
      return widget.portfolioData!.positions.firstWhere(
        (p) => p.ticker.toUpperCase() == ticker.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  List<StrategyStock> get _filteredStocks {
    return MillionDollarPortfolio.stocks.where((stock) {
      final matchesSearch = stock.ticker.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stock.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stock.sector.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedSector == 'Всі') return true;
      if (_selectedSector == 'В портфелі') {
        return _findPosition(stock.ticker) != null;
      }
      return stock.sector == _selectedSector;
    }).toList();
  }

  Future<void> _confirmAndInvestAll() async {
    final availableCash = widget.portfolioData?.cash ?? 0.0;
    const requiredCash = 40.0;

    if (availableCash < requiredCash) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber[900],
          content: Text(
            'Недостатньо кешу для плану (\$40). Доступно: \$${availableCash.toStringAsFixed(2)}. Поповніть баланс!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFF00FF94)),
            SizedBox(width: 8),
            Text('Інвестувати \$40?'),
          ],
        ),
        content: Text(
          'Буде автоматично придбано частки всіх 40 акцій стратегії «Million Dollar Way» по \$1 у кожну позицію.\n\n'
          'Доступний кеш: \$${availableCash.toStringAsFixed(2)}\n'
          'Залишок після інвестиції: \$${(availableCash - requiredCash).toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00FF94),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Підтвердити', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBatchInvesting = true);
    try {
      final stockPayload = MillionDollarPortfolio.stocks.map((s) => s.toJson()).toList();
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/strategy/invest-plan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'amount_per_stock': 1.0,
          'stocks': stockPayload,
        }),
      );

      if (res.statusCode == 200) {
        widget.onRefreshPortfolio();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF00FF94),
              content: Text(
                '🎉 План виконано! Успішно інвестовано \$40 (по \$1 у всі 40 акцій)!',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
              ),
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
      if (mounted) setState(() => _isBatchInvesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stocks = _filteredStocks;
    final ownedCount = MillionDollarPortfolio.stocks.where((s) => _findPosition(s.ticker) != null).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _buildHeroBanner(ownedCount),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildSectorChips(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'АКЦІЇ СТРАТЕГІЇ (${stocks.length})',
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              Text(
                'Зібрано: $ownedCount з 40',
                style: const TextStyle(color: Color(0xFF00FF94), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...stocks.map((stock) => _buildStockCard(stock)),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(int ownedCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161F36), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF94).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎯 Million Dollar Way', style: TextStyle(color: Color(0xFF00FF94), fontWeight: FontWeight.w900, fontSize: 12)),
                    SizedBox(width: 4),
                    InfoButton(topic: InfoTopic.strategy40, size: 14),
                  ],
                ),
              ),
              const Spacer(),
              const Text('40 ТОП-АКЦІЙ', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Оптимізований Портфель', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          const Text('План: \$160/місяць (\$40 на тиждень), по \$1 на кожну позицію.', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ownedCount / 40.0,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00FF94)),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00FF94),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isBatchInvesting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.bolt_rounded, size: 22),
              label: Text(
                _isBatchInvesting ? 'Інвестування...' : '⚡ Інвестувати \$40 (по \$1 у всі 40 акцій)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              onPressed: _isBatchInvesting ? null : _confirmAndInvestAll,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        style: const TextStyle(fontSize: 14),
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: const InputDecoration(
          hintText: 'Пошук серед 40 акцій (назва, тікер, сектор)...',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.white54, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSectorChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _sectors.map((sec) {
          final isSel = _selectedSector == sec;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSel,
              label: Text(sec, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
              selectedColor: const Color(0xFF00FF94).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFF00FF94),
              backgroundColor: const Color(0xFF161B26),
              side: BorderSide(color: isSel ? const Color(0xFF00FF94) : Colors.white10),
              onSelected: (_) => setState(() => _selectedSector = sec),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStockCard(StrategyStock stock) {
    final pos = _findPosition(stock.ticker);
    final isOwned = pos != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOwned ? const Color(0xFF00FF94).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            StockDetailSheet.show(
              context,
              token: widget.token,
              ticker: stock.ticker,
              name: stock.name,
              sector: stock.sector,
              currentPrice: pos?.currentPrice ?? stock.defaultPrice,
              description: stock.description,
              ownedPosition: pos,
              onPortfolioUpdated: widget.onRefreshPortfolio,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                StockLogo(
                  ticker: stock.ticker,
                  size: 44,
                  borderRadius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(stock.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(stock.sector, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          if (isOwned) ...[
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            const SizedBox(width: 6),
                            Text('${pos.shares.toStringAsFixed(4)} шт.', style: const TextStyle(color: Color(0xFF00FF94), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${(pos?.currentPrice ?? stock.defaultPrice).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOwned ? const Color(0xFF00FF94).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOwned ? 'В портфелі' : '+\$1 Додати',
                        style: TextStyle(
                          color: isOwned ? const Color(0xFF00FF94) : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../widgets/stock_logo.dart';
import '../widgets/info_helper_sheet.dart';
import '../widgets/ibkr_connection_result_dialog.dart';
import 'history_screen.dart';
import 'settings_sheet.dart';
import 'simulator_screen.dart';
import 'stock_detail_sheet.dart';
import 'strategy_screen.dart';

class PortfolioScreen extends StatefulWidget {
  final String token;

  const PortfolioScreen({super.key, required this.token});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  int _selectedTabIndex = 0;
  late Future<PortfolioData> _portfolioFuture;
  PortfolioData? _latestData;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    SessionStore.readEmail().then((em) {
      if (mounted) setState(() => _userEmail = em ?? '');
    });
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _portfolioFuture = _fetchPortfolio();
    });
  }

  Future<PortfolioData> _fetchPortfolio() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/portfolio'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (res.statusCode == 200) {
      final data = PortfolioData.fromJson(jsonDecode(res.body));
      if (mounted) setState(() => _latestData = data);
      return data;
    }
    throw Exception('Помилка завантаження даних (код ${res.statusCode})');
  }

  Future<void> _logout() async {
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}
    await SessionStore.deleteToken();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  Future<void> _depositCash(double amount) async {
    if (amount <= 0) return;
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/cash/deposit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'amount': amount}),
      );
      if (res.statusCode == 200) {
        _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF00FF94),
              content: Text('Баланс успішно поповнено на \$$amount', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка: $e')));
      }
    }
  }

  Future<void> _sellShares(String ticker, double shares, double price) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/transactions/sell'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'ticker': ticker, 'shares': shares, 'price': price}),
      );
      if (res.statusCode == 200) {
        _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF00E5FF),
              content: Text('Успішно продано ${shares.toStringAsFixed(4)} шт $ticker', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка: ${res.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка: $e')));
      }
    }
  }

  void _showDepositDialog() {
    final ctrl = TextEditingController(text: '160');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00FF94)),
            SizedBox(width: 10),
            Text('Поповнити баланс'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Вкажіть суму для зарахування:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сума (\$)'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [40, 160, 500, 1000].map((v) {
                return ActionChip(
                  label: Text('+\$$v', style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFF1E2433),
                  onPressed: () => ctrl.text = v.toString(),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати', style: TextStyle(color: Colors.white54))),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00FF94),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final amount = double.tryParse(ctrl.text) ?? 0;
              Navigator.pop(ctx);
              _depositCash(amount);
            },
            child: const Text('Поповнити', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showSellDialog(Position pos) {
    final sharesCtrl = TextEditingController(text: pos.shares.toString());
    final priceCtrl = TextEditingController(text: pos.currentPrice.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Продати ${pos.ticker}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Доступно: ${pos.shares.toStringAsFixed(4)} шт. • Ринкова: \$${pos.currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: sharesCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Кількість для продажу (шт.)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Ціна продажу (\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати', style: TextStyle(color: Colors.white54))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final s = double.tryParse(sharesCtrl.text) ?? 0;
              final p = double.tryParse(priceCtrl.text) ?? 0;
              Navigator.pop(ctx);
              _sellShares(pos.ticker, s, p);
            },
            child: const Text('Продати', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    SettingsSheet.show(
      context,
      token: widget.token,
      onDepositRequested: _showDepositDialog,
      onLogoutRequested: _logout,
      onPortfolioUpdated: _refreshData,
    );
  }

  Future<void> _setupDemoIBKRAndSwitch() async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/ibkr/config'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'flex_token': 'DEMO_IBKR', 'query_id': 'DEMO'}),
      );
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final result = IBKRResult.fromJson(body);

      // Set mode to real
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/portfolio/mode'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'mode': 'real'}),
      );

      _refreshData();

      if (mounted) {
        IBKRConnectionResultDialog.show(
          context,
          result: result,
          isAdmin: SessionStore.isAdmin(_userEmail),
          onRetry: () => _syncIBKRFromPortfolio(showDialogResult: true),
          onOpenGuide: _openSettings,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка підключення Demo IBKR: $e')),
        );
      }
    }
  }

  Future<void> _syncIBKRFromPortfolio({bool showDialogResult = false}) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/ibkr/sync'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final result = IBKRResult.fromJson(body);
      _refreshData();

      if (mounted) {
        if (showDialogResult || !result.isSuccess) {
          IBKRConnectionResultDialog.show(
            context,
            result: result,
            isAdmin: SessionStore.isAdmin(_userEmail),
            onRetry: () => _syncIBKRFromPortfolio(showDialogResult: true),
            onOpenGuide: _openSettings,
            onTryDemo: _setupDemoIBKRAndSwitch,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF00FF94),
              content: Text(
                'Синхронізація IBKR успішна! Оновлено ${result.positionsCount} позицій (Кеш: \$${result.cash.toStringAsFixed(2)})',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errResult = IBKRResult(
          isSuccess: false,
          status: 'error',
          accountId: _latestData?.ibkrAccountId ?? '',
          positionsCount: 0,
          cash: 0,
          friendlyMessage: 'Помилка синхронізації IBKR: ${e.toString().replaceAll("Exception: ", "")}',
          errorMessage: e.toString(),
        );
        IBKRConnectionResultDialog.show(
          context,
          result: errResult,
          isAdmin: SessionStore.isAdmin(_userEmail),
          onRetry: () => _syncIBKRFromPortfolio(showDialogResult: true),
          onOpenGuide: _openSettings,
          onTryDemo: _setupDemoIBKRAndSwitch,
        );
      }
    }
  }

  Future<void> _confirmSwitchMode(bool toReal) async {
    if (toReal && (_latestData?.ibkrConfigured != true)) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF00E5FF)),
              SizedBox(width: 8),
              Expanded(child: Text('Підключення до IBKR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: const Text(
            'Рахунок Interactive Brokers ще не налаштовано!\n\n'
            'Щоб бачити дані реального рахунку, ви можете ввести числовий токен Flex Query, або спробувати миттєвий тестовий демо-рахунок з живими біржовими даними.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Скасувати', style: TextStyle(color: Colors.white54)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00E5FF)),
              icon: const Icon(Icons.key_rounded, size: 16),
              label: const Text('Ввести токен'),
              onPressed: () => Navigator.pop(ctx, 'input'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FF94), foregroundColor: Colors.black),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
              label: const Text('Швидкий тест IBKR', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(ctx, 'demo'),
            ),
          ],
        ),
      );

      if (choice == 'demo') {
        await _setupDemoIBKRAndSwitch();
        return;
      } else if (choice == 'input') {
        _openSettings();
        return;
      } else {
        return;
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(
              toReal ? Icons.warning_amber_rounded : Icons.sports_esports_rounded,
              color: toReal ? const Color(0xFFFFB74D) : const Color(0xFF00FF94),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                toReal ? 'Перехід у РЕАЛЬНИЙ режим' : 'Повернення у ДЕМО-режим',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          toReal
              ? '⚠️ УВАГА: Ви перемикаєтесь на відображення РЕАЛЬНИХ активів брокерського рахунку Interactive Brokers (IBKR).\n\n'
                  '• Баланси та позиції відображатимуть фактичний стан рахунку за останнім Flex Query.\n'
                  '• Віртуальні демо-угоди та тестовий баланс буде приховано.\n\n'
                  'Підтвердити перехід на реальні дані?'
              : '🎮 Ви повертаєтесь до безпечного ДЕМО-симулятора Million Dollar Way.\n\n'
                  '• Фактичні баланси IBKR будуть приховані.\n'
                  '• Ви зможете вільно тестувати розподіл на 40 акцій без фінансового ризику.\n\n'
                  'Повернутися до демо-режиму?',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: toReal ? const Color(0xFFFFB74D) : const Color(0xFF00FF94),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              toReal ? 'Так, увімкнути IBKR' : 'Так, перейти у Демо',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/portfolio/mode'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'mode': toReal ? 'real' : 'demo'}),
      );
      if (res.statusCode == 200) {
        _refreshData();
        if (toReal && (_latestData?.ibkrConfigured == true)) {
          _syncIBKRFromPortfolio(showDialogResult: true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: toReal ? const Color(0xFF00FF94) : const Color(0xFF00E5FF),
              content: Text(
                toReal
                    ? '🟢 Режим змінено: Реальні дані (Interactive Brokers)'
                    : '🎮 Режим змінено: Демо-симулятор',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка зміни режиму: $e')),
        );
      }
    }
  }
  void _showBuyDialog(double currentCash) {
    final tickerCtrl = TextEditingController();
    final dollarsCtrl = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Купити акцію', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text('Кеш: \$${currentCash.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00FF94), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            StatefulBuilder(
              builder: (context, setModalState) {
                final currentTicker = tickerCtrl.text.trim().toUpperCase();
                return Column(
                  children: [
                    Row(
                      children: [
                        if (currentTicker.isNotEmpty) ...[
                          StockLogo(ticker: currentTicker, size: 40, borderRadius: 12),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: TextField(
                            controller: tickerCtrl,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (_) => setModalState(() {}),
                            decoration: const InputDecoration(labelText: 'Тікер (напр. AAPL, NVDA, VOO)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['VOO', 'AAPL', 'NVDA', 'MSFT', 'AMZN', 'GOOGL', 'TSLA'].map((t) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: StockLogo(ticker: t, size: 16, borderRadius: 4),
                              label: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                setModalState(() {
                                  tickerCtrl.text = t;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dollarsCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сума купівлі (\$)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF94),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final ticker = tickerCtrl.text.trim().toUpperCase();
                  final dollars = double.tryParse(dollarsCtrl.text) ?? 0;
                  if (ticker.isEmpty || dollars <= 0) return;
                  Navigator.pop(ctx);
                  await _buyDollarAmount(ticker, dollars);
                },
                child: const Text('Купити зараз', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buyDollarAmount(String ticker, double dollars) async {
    try {
      final qRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/market/quote?ticker=$ticker'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      double price = 100.0;
      if (qRes.statusCode == 200) {
        final qData = jsonDecode(qRes.body);
        price = (qData['price'] as num?)?.toDouble() ?? 100.0;
      }
      final shares = dollars / price;
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'ticker': ticker,
          'asset_class': 'Stock',
          'shares': shares,
          'price': price,
        }),
      );
      if (res.statusCode == 200) {
        _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: const Color(0xFF00FF94), content: Text('Куплено $ticker на \$$dollars!', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          );
        }
      } else {
        throw Exception(res.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00FF94), Color(0xFF00E5FF)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.appTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(AppStrings.appSubtitle, style: TextStyle(color: Color(0xFF00FF94), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Поповнити кеш',
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF00FF94)),
            onPressed: _showDepositDialog,
          ),
          IconButton(
            tooltip: 'Меню та налаштування',
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildHomeFutureBody(),
          StrategyScreen(
            token: widget.token,
            portfolioData: _latestData,
            onRefreshPortfolio: _refreshData,
          ),
          SimulatorScreen(
            token: widget.token,
            isTab: true,
          ),
          HistoryScreen(
            token: widget.token,
            isTab: true,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121622),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          onTap: (i) => setState(() => _selectedTabIndex = i),
          backgroundColor: const Color(0xFF121622),
          selectedItemColor: const Color(0xFF00FF94),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Портфель',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_outlined),
              activeIcon: Icon(Icons.track_changes_rounded),
              label: 'Стратегія 40',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph_outlined),
              activeIcon: Icon(Icons.auto_graph_rounded),
              label: 'Аналітика',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Історія',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeFutureBody() {
    return FutureBuilder<PortfolioData>(
      future: _portfolioFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _latestData == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF94)));
        }
        if (snapshot.hasError && _latestData == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Помилка: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _refreshData, child: const Text('Спробувати знову')),
              ],
            ),
          );
        }
        final data = snapshot.data ?? _latestData!;
        return RefreshIndicator(
          color: const Color(0xFF00FF94),
          onRefresh: () async => _refreshData(),
          child: _buildHomeContent(data),
        );
      },
    );
  }

  Widget _buildHomeContent(PortfolioData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        _buildModeBannerCard(data),
        const SizedBox(height: 14),
        _buildGoalMilestoneCard(data),
        const SizedBox(height: 14),
        _buildHeaderCard(data),
        const SizedBox(height: 14),
        _buildMetricsRow(data),
        const SizedBox(height: 14),
        _buildQuickActionsRow(data),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              data.mode == 'real'
                  ? 'АКТИВИ IBKR (РЕАЛЬНИЙ РАХУНОК)'
                  : 'АКТИВНІ ПОЗИЦІЇ (СИМУЛЯТОР)',
              style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            Text('${data.positions.length} активів', style: const TextStyle(color: Color(0xFF00FF94), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        if (data.positions.isEmpty)
          (data.mode == 'real' ? _buildIBKREmptyCard(data) : _buildDemoEmptyCard())
        else
          ...data.positions.map((pos) => _buildPositionCard(pos)),
      ],
    );
  }

  Widget _buildDemoEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Icon(Icons.rocket_launch_outlined, size: 40, color: Color(0xFF00FF94)),
          const SizedBox(height: 10),
          const Text('Почніть формування портфеля!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Перейдіть у вкладку "Стратегія 40" та купуйте найкращі акції за планом.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00FF94),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => setState(() => _selectedTabIndex = 1),
            icon: const Icon(Icons.track_changes_rounded),
            label: const Text('Відкрити Стратегію 40', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildIBKREmptyCard(PortfolioData data) {
    final isConfigured = data.ibkrConfigured;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF94).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hub_rounded, size: 38, color: Color(0xFF00FF94)),
          ),
          const SizedBox(height: 12),
          Text(
            isConfigured ? 'Рахунок IBKR очікує синхронізації' : 'Рахунок Interactive Brokers не підключено',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            isConfigured
                ? 'Налаштування підключення збережено. Натисніть кнопку нижче, щоб отримати позиції та баланс кешу з IBKR.'
                : 'Для завантаження реального портфеля введіть цифровий токен Flex Query, або спробуйте живий демонстраційний рахунок.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (isConfigured) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF94),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Синхронізувати з IBKR зараз', style: TextStyle(fontWeight: FontWeight.w900)),
                onPressed: () => _syncIBKRFromPortfolio(showDialogResult: true),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Змінити налаштування Flex Query'),
              onPressed: _openSettings,
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF94),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('🚀 Швидкий тест IBKR (Live Demo)', style: TextStyle(fontWeight: FontWeight.w900)),
                onPressed: _setupDemoIBKRAndSwitch,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                  side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.key_rounded, size: 16),
                label: const Text('🔑 Ввести мій токен Flex Query', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _openSettings,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeBannerCard(PortfolioData data) {
    final bool isReal = data.mode == 'real';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReal ? const Color(0xFF00FF94).withValues(alpha: 0.35) : const Color(0xFF00E5FF).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isReal ? const Color(0xFF00FF94).withValues(alpha: 0.15) : const Color(0xFF00E5FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isReal ? Icons.verified_rounded : Icons.sports_esports_rounded,
              color: isReal ? const Color(0xFF00FF94) : const Color(0xFF00E5FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isReal ? 'РЕАЛЬНИЙ IBKR' : 'ДЕМО-СИМУЛЯТОР',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: isReal ? const Color(0xFF00FF94) : const Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isReal ? const Color(0xFF00FF94).withValues(alpha: 0.15) : const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isReal ? 'LIVE' : 'VIRTUAL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isReal ? const Color(0xFF00FF94) : const Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isReal
                      ? (data.ibkrAccountId?.isNotEmpty == true
                          ? 'Акаунт: ${data.ibkrAccountId}'
                          : 'Синхронізація через Flex Web Service')
                      : 'Навчальний портфель Million Dollar Way',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isReal && data.ibkrConfigured) ...[
            IconButton(
              tooltip: 'Синхронізувати з IBKR',
              icon: const Icon(Icons.sync_rounded, color: Color(0xFF00FF94), size: 20),
              onPressed: _syncIBKRFromPortfolio,
            ),
          ],
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => _confirmSwitchMode(!isReal),
            child: Text(
              isReal ? 'В Демо' : 'В IBKR',
              style: TextStyle(
                color: isReal ? const Color(0xFF00E5FF) : const Color(0xFF00FF94),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildGoalMilestoneCard(PortfolioData data) {
    const double goal = 1000000.0;
    final progress = (data.totalValue / goal).clamp(0.0, 1.0);
    final percent = (data.totalValue / goal * 100).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00FF94).withValues(alpha: 0.12),
            const Color(0xFF00E5FF).withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF00FF94).withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF00FF94), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('ЦІЛЬ: \$1,000,000 (MILLION DOLLAR WAY)', style: TextStyle(color: Color(0xFF00FF94), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                        const SizedBox(width: 4),
                        const InfoButton(topic: InfoTopic.millionGoal, size: 14),
                      ],
                    ),
                    const Text('Дисципліна щотижневого інвестування', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              Text('$percent%', style: const TextStyle(color: Color(0xFF00FF94), fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress < 0.005 ? 0.005 : progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF94)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\$${data.totalValue.toStringAsFixed(0)} накопичено', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const Text('Ціль: \$1,000,000', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(PortfolioData data) {
    return Row(
      children: [
        Expanded(
          child: _quickActionButton(
            icon: Icons.add_shopping_cart_rounded,
            label: 'Купити',
            color: const Color(0xFF00FF94),
            textColor: Colors.black,
            isFilled: true,
            onTap: () => _showBuyDialog(data.cash),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quickActionButton(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Поповнити',
            color: Colors.white,
            textColor: Colors.white,
            isFilled: false,
            onTap: _showDepositDialog,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quickActionButton(
            icon: Icons.track_changes_rounded,
            label: 'План 40',
            color: const Color(0xFF00E5FF),
            textColor: const Color(0xFF00E5FF),
            isFilled: false,
            onTap: () => setState(() => _selectedTabIndex = 1),
          ),
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required bool isFilled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isFilled ? color : const Color(0xFF161B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isFilled ? Colors.transparent : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isFilled ? Colors.black : color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(PortfolioData data) {
    final isPositive = data.totalPnL >= 0;
    final pnlColor = isPositive ? const Color(0xFF00FF94) : Colors.redAccent;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ЗАГАЛЬНА ВАРТІСТЬ ПОРТФЕЛЯ', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text('\$${data.totalValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: pnlColor, size: 18),
              const SizedBox(width: 4),
              Text(
                '$sign\$${data.totalPnL.toStringAsFixed(2)} ($sign${data.totalPnLPercent.toStringAsFixed(2)}%)',
                style: TextStyle(color: pnlColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              const Text('Реальний ринок', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(PortfolioData data) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('ВІЛЬНИЙ КЕШ', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800)),
                    SizedBox(width: 4),
                    InfoButton(topic: InfoTopic.freeCash, size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Text('\$${data.cash.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00FF94))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('ВКЛАДЕНО', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800)),
                    SizedBox(width: 4),
                    InfoButton(topic: InfoTopic.investedTotal, size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Text('\$${data.investedValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatAssetClass(String? raw) {
    if (raw == null || raw.isEmpty) return 'Акція';
    switch (raw.toUpperCase()) {
      case 'EQUITY':
      case 'STOCK':
        return 'Акція';
      case 'ETF':
        return 'ETF Фонд';
      case 'CRYPTO':
        return 'Крипто';
      case 'BOND':
        return 'Облігація';
      default:
        return raw;
    }
  }

  Widget _buildPositionCard(Position pos) {
    final isPos = pos.unrealizedPnL >= 0;
    final pnlColor = isPos ? const Color(0xFF00FF94) : Colors.redAccent;
    final sign = isPos ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            StockDetailSheet.show(
              context,
              token: widget.token,
              ticker: pos.ticker,
              name: pos.companyName.isNotEmpty ? pos.companyName : pos.ticker,
              sector: _formatAssetClass(pos.assetClass),
              currentPrice: pos.currentPrice,
              description: 'Позиція у вашому портфелі.',
              ownedPosition: pos,
              onPortfolioUpdated: _refreshData,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    StockLogo(
                      ticker: pos.ticker,
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
                              Text(pos.ticker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                                child: Text(_formatAssetClass(pos.assetClass), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                              ),
                              const SizedBox(width: 2),
                              const InfoButton(topic: InfoTopic.assetClass, size: 13),
                            ],
                          ),
                          if (pos.companyName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(pos.companyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${pos.totalValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        Text(
                          'Ринкова: \$${pos.currentPrice.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFF00FF94), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${pos.shares} шт. • Сер.: \$${pos.averageBuyPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(width: 2),
                            const InfoButton(topic: InfoTopic.avgPrice, size: 13),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text('Прибуток: $sign\$${pos.unrealizedPnL.toStringAsFixed(2)} ($sign${pos.unrealizedPnLPercent.toStringAsFixed(1)}%)',
                                style: TextStyle(color: pnlColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 2),
                            const InfoButton(topic: InfoTopic.unrealizedPnL, size: 13),
                          ],
                        ),
                      ],
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      ),
                      onPressed: () => _showSellDialog(pos),
                      child: const Text('Продати', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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



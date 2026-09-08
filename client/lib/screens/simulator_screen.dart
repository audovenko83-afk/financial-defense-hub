import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../widgets/stock_logo.dart';
import '../widgets/interactive_stock_chart.dart';
import '../widgets/info_helper_sheet.dart';

class SimulatorScreen extends StatefulWidget {
  final String token;
  final bool isTab;
  final VoidCallback? onUnauthorized;

  const SimulatorScreen({super.key, required this.token, this.isTab = false, this.onUnauthorized});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final capitalCtrl = TextEditingController(text: '1000');
  final monthlyCtrl = TextEditingController(text: '160');
  final yearsCtrl = TextEditingController(text: '20');
  final returnCtrl = TextEditingController(text: '10.2');
  final divCtrl = TextEditingController(text: '1.8');
  final tickerCtrl = TextEditingController(text: 'VOO');

  bool isLoading = false;
  List<dynamic> scenarios = [];
  List<dynamic> historicalPoints = [];
  bool isLoadingHistory = false;
  String _selectedHistoryRange = '1y';

  @override
  void initState() {
    super.initState();
    _fetchHistory('VOO');
    _runSimulation();
  }

  Future<void> _fetchHistory(String ticker, [String? range]) async {
    ticker = ticker.trim().toUpperCase();
    if (ticker.isEmpty) return;
    if (range != null) _selectedHistoryRange = range;
    setState(() => isLoadingHistory = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/market/history?ticker=$ticker&range=$_selectedHistoryRange'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() => historicalPoints = data['points'] as List? ?? []);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => isLoadingHistory = false);
  }

  Future<void> _runSimulation() async {
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/simulator'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: jsonEncode({
          'starting_capital': double.tryParse(capitalCtrl.text) ?? 1000,
          'monthly_contribution': double.tryParse(monthlyCtrl.text) ?? 160,
          'years': int.tryParse(yearsCtrl.text) ?? 20,
          'annual_return': double.tryParse(returnCtrl.text) ?? 10.2,
          'dividend_yield': double.tryParse(divCtrl.text) ?? 1.8,
          'reinvest_dividends': true,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => scenarios = data['scenarios'] as List? ?? []);
      } else if (res.statusCode == 401) {
        widget.onUnauthorized?.call();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.isTab
          ? null
          : AppBar(
              title: const Text('Аналітика та Симулятор \$1М', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 14),
          _buildInputsCard(),
          const SizedBox(height: 16),
          _buildScenariosSection(),
          const SizedBox(height: 16),
          _buildMarketHistoryCard(),
          const SizedBox(height: 16),
          _buildHowAnalyticsWorksCard(),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF132A24), Color(0xFF0F1A24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded, color: Color(0xFF00FF94), size: 20),
              SizedBox(width: 8),
              Text('ОРІЄНТИР РИНКУ S&P 500', style: TextStyle(color: Color(0xFF00FF94), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
              Spacer(),
              InfoButton(topic: InfoTopic.analyticsEngine, size: 16),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Історична середня дохідність провідних компаній становить ~10.2% річних. '
            'Вкладаючи \$160/місяць у 40 топових акцій, складний відсоток примножує капітал швидше з кожним роком.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ПАРАМЕТРИ НАКОПИЧЕННЯ', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: capitalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Старт (\$)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: monthlyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Внесок/міс (\$)'))),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Пресети:', style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('\$160/міс (План 40)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () => setState(() => monthlyCtrl.text = '160'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('\$300/міс', style: TextStyle(fontSize: 10)),
                  onPressed: () => setState(() => monthlyCtrl.text = '300'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('\$500/міс', style: TextStyle(fontSize: 10)),
                  onPressed: () => setState(() => monthlyCtrl.text = '500'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: yearsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Років'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: returnCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Дохідність %'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: divCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Дивіденди %'))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00FF94),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isLoading ? null : _runSimulation,
              icon: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.calculate_rounded),
              label: const Text('Розрахувати сценарії капіталу', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenariosSection() {
    if (scenarios.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ПРОГНОЗОВАНІ СЦЕНАРІЇ РОЗВИТКУ', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        ...scenarios.map((sc) {
          final name = sc['scenario'] ?? sc['name'] ?? 'Сценарій';
          final cap = (sc['final_value'] ?? sc['final_capital'] as num?)?.toDouble() ?? 0;
          final div = (sc['total_dividends'] ?? sc['annual_dividend_income'] as num?)?.toDouble() ?? 0;
          final targetYear = (sc['target_year'] as num?)?.toInt() ?? 0;
          final isMillion = cap >= 1000000;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isMillion ? const Color(0xFF00FF94).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (isMillion) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF00FF94).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('ЦІЛЬ \$1M 🎯', style: TextStyle(color: Color(0xFF00FF94), fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (targetYear > 0)
                      Text('Ціль \$1 000 000: через $targetYear р.', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold))
                    else
                      const Text('Накопичувальний результат', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${cap.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00FF94), fontSize: 17)),
                    Text('+\$${div.toStringAsFixed(0)} дивідендів', style: const TextStyle(color: Color(0xFFFFC857), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMarketHistoryCard() {
    final cleanTicker = tickerCtrl.text.trim().toUpperCase();
    final chartPoints = historicalPoints
        .map((p) => ChartPoint(
              date: p['date']?.toString() ?? '',
              close: (p['close'] as num?)?.toDouble() ?? 0.0,
            ))
        .where((p) => p.close > 0)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (cleanTicker.isNotEmpty) ...[
                StockLogo(ticker: cleanTicker, size: 28, borderRadius: 8),
                const SizedBox(width: 8),
              ],
              const Expanded(
                child: Text(
                  'БІРЖОВІ ДАНІ ТА ІСТОРІЯ ЦІН (YAHOO FINANCE)',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tickerCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Тікер біржі (напр. VOO, AAPL, NVDA)',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFF00FF94),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _fetchHistory(tickerCtrl.text),
                child: const Text('Завантажити', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InteractiveStockChart(
            points: chartPoints,
            selectedRange: _selectedHistoryRange,
            isLoading: isLoadingHistory,
            onRangeChanged: (r) => _fetchHistory(tickerCtrl.text, r),
          ),
        ],
      ),
    );
  }
  Widget _buildHowAnalyticsWorksCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF00FF94).withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.psychology_rounded, color: Color(0xFF00FF94), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ЯК ПРАЦЮЄ АНАЛІТИКА?', style: TextStyle(color: Color(0xFF00FF94), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    Text('Звідки беруться цифри та формули', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              const InfoButton(topic: InfoTopic.analyticsEngine, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          _buildAnalyticsFact(
            icon: Icons.language_rounded,
            title: '1. Реальні котирування бірж NYSE та NASDAQ',
            desc: 'Ціни акцій та графіки надходять через Yahoo Finance API безпосередньо з американських бірж у реальному часі.',
          ),
          const SizedBox(height: 10),
          _buildAnalyticsFact(
            icon: Icons.calculate_rounded,
            title: '2. Середня ціна та прибуток (PnL)',
            desc: 'Середньозважена ціна купівлі згладжує ринкові сплески. PnL = (Поточна ціна - Середня ціна) × Кількість акцій.',
          ),
          const SizedBox(height: 10),
          _buildAnalyticsFact(
            icon: Icons.timeline_rounded,
            title: '3. Математика симулятора \$1,000,000',
            desc: 'Модель використовує формулу складного відсотка на основі 50-річної статистики S&P 500 (~10.2% річних) з щомісячним внеском.',
          ),
          const SizedBox(height: 10),
          _buildAnalyticsFact(
            icon: Icons.autorenew_rounded,
            title: '4. Реінвестування дивідендів',
            desc: 'Дивідендний потік (~1.8% річних) не витрачається, а реінвестується у нові частки компаній, прискорюючи зростання капіталу.',
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsFact({required IconData icon, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

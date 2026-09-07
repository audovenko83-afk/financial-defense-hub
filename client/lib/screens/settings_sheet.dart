import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

class SettingsSheet extends StatefulWidget {
  final String token;
  final VoidCallback onDepositRequested;
  final VoidCallback onLogoutRequested;

  const SettingsSheet({
    super.key,
    required this.token,
    required this.onDepositRequested,
    required this.onLogoutRequested,
  });

  static void show(
    BuildContext context, {
    required String token,
    required VoidCallback onDepositRequested,
    required VoidCallback onLogoutRequested,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettingsSheet(
        token: token,
        onDepositRequested: onDepositRequested,
        onLogoutRequested: onLogoutRequested,
      ),
    );
  }

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  String? _email;
  final _serverUrlCtrl = TextEditingController(text: ApiConfig.baseUrl);
  String _pingResult = '';
  bool _isTesting = false;
  bool _biometricsEnabled = true;

  @override
  void initState() {
    super.initState();
    SessionStore.readEmail().then((v) {
      if (mounted) setState(() => _email = v);
    });
    SessionStore.isBiometricsEnabled().then((v) {
      if (mounted) setState(() => _biometricsEnabled = v);
    });
  }

  Future<void> _testPing() async {
    setState(() {
      _isTesting = true;
      _pingResult = 'Перевірка...';
    });
    try {
      final url = _serverUrlCtrl.text.trim();
      final uri = Uri.parse(url.endsWith('/ping') ? url : '$url/ping');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        setState(() => _pingResult = '🟢 Сервер доступний (200 OK)');
      } else {
        setState(() => _pingResult = '⚠️ Помилка: статус ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _pingResult = '🔴 Немає звʼязку ($e)');
    } finally {
      setState(() => _isTesting = false);
    }
  }
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Видалити акаунт?', style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'Ви впевнені, що хочете видалити свій обліковий запис? Цю дію неможливо скасувати. Всі ваші дані, активи та історія будуть видалені назавжди.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати', style: TextStyle(color: Colors.white54))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/auth/account'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          widget.onLogoutRequested();
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


  Future<void> _saveServerUrl(String url) async {
    await ApiConfig.setBaseUrl(url);
    _serverUrlCtrl.text = ApiConfig.baseUrl;
    _testPing();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF00FF94), content: Text('Адресу сервера оновлено!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.tune_rounded, color: Color(0xFF00FF94)),
                SizedBox(width: 10),
                Text('Налаштування та Меню', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 16),
            _buildProfileCard(),
            const SizedBox(height: 14),
            _buildSecurityCard(),
            const SizedBox(height: 14),
            _buildStrategyCard(),
            if (SessionStore.isAdmin(_email)) ...[
              const SizedBox(height: 14),
              _buildServerCard(),
            ],
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 24),
            _buildFooterInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Column(
      children: [
        Center(
          child: TextButton(
            onPressed: () async {
              final url = Uri.parse('https://cream-lion-12hfp5j.mystrikingly.com/blog/privacy-policy-for-million-dollar-way');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                await launchUrl(url, mode: LaunchMode.inAppWebView);
              }
            },
            child: const Text('Політика конфіденційності', style: TextStyle(color: Colors.white54, fontSize: 12, decoration: TextDecoration.underline)),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Відмова від відповідальності (Disclaimer): Million Dollar Way є аналітичним інструментом і симулятором виключно для навчальних цілей та бюджетування. Він не надає ліцензованих фінансових чи інвестиційних порад. Будь-які капіталовкладення несуть ризики втрати коштів через ринкові коливання.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white30, fontSize: 10, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF94).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF00FF94), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Біометрія (Відбиток / Face ID)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 2),
                Text('Швидкий та захищений вхід у додаток', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: _biometricsEnabled,
            activeThumbColor: const Color(0xFF00FF94),
            onChanged: (val) async {
              setState(() => _biometricsEnabled = val);
              await SessionStore.setBiometricsEnabled(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final bool isAdmin = SessionStore.isAdmin(_email);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAdmin ? const Color(0xFFFFD700).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isAdmin
                ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                : const Color(0xFF00FF94).withValues(alpha: 0.15),
            child: Icon(
              isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
              color: isAdmin ? const Color(0xFFFFD700) : const Color(0xFF00FF94),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _email ?? 'Користувач',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Адмін',
                          style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  isAdmin ? 'Адміністратор системи • Повний доступ' : 'Авторизовано • Сесія активна',
                  style: TextStyle(color: isAdmin ? const Color(0xFFFFD700).withValues(alpha: 0.8) : Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF172554), Color(0xFF1E1B4B)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes_rounded, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 8),
              Text('Стратегія «Million Dollar Way»', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00E5FF))),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• 40 найкращих американських акцій із диверсифікацією.\n'
            '• План: \$160/міс (\$40 щотижня), по \$1 на кожну позицію.\n'
            '• Складний відсоток та реінвестування ведуть до \$1 000 000.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('СЕРВЕР ТА СИНХРОНІЗАЦІЯ', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          TextField(
            controller: _serverUrlCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'API Base URL',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                tooltip: 'Перевірити звʼязок',
                icon: _isTesting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF94)))
                    : const Icon(Icons.network_check_rounded, color: Color(0xFF00FF94)),
                onPressed: _testPing,
              ),
            ),
          ),
          if (_pingResult.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_pingResult, style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.cloud_done, size: 14, color: Color(0xFF00FF94)),
                label: const Text('Render Cloud', style: TextStyle(fontSize: 10)),
                onPressed: () => _saveServerUrl('https://audovenko-mdw-apits.onrender.com/api'),
              ),
              ActionChip(
                label: const Text('127.0.0.1 (ADB)', style: TextStyle(fontSize: 10)),
                onPressed: () => _saveServerUrl('http://127.0.0.1:8080/api'),
              ),
              ActionChip(
                label: const Text('192.168.0.7 (LAN)', style: TextStyle(fontSize: 10)),
                onPressed: () => _saveServerUrl('http://192.168.0.7:8080/api'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00FF94),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text('Поповнити баланс кешу', style: TextStyle(fontWeight: FontWeight.w900)),
            onPressed: () {
              Navigator.pop(context);
              widget.onDepositRequested();
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Вийти з облікового запису', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              widget.onLogoutRequested();
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 20),
            label: const Text('Видалити обліковий запис', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _deleteAccount,
          ),
        ),
      ],
    );
  }
}

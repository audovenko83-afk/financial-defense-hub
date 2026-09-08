import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../widgets/admin_users_sheet.dart';
import '../widgets/ibkr_connection_result_dialog.dart';

class SettingsSheet extends StatefulWidget {
  final String token;
  final VoidCallback onDepositRequested;
  final VoidCallback onLogoutRequested;
  final VoidCallback? onPortfolioUpdated;

  const SettingsSheet({
    super.key,
    required this.token,
    required this.onDepositRequested,
    required this.onLogoutRequested,
    this.onPortfolioUpdated,
  });

  static void show(
    BuildContext context, {
    required String token,
    required VoidCallback onDepositRequested,
    required VoidCallback onLogoutRequested,
    VoidCallback? onPortfolioUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettingsSheet(
        token: token,
        onDepositRequested: onDepositRequested,
        onLogoutRequested: onLogoutRequested,
        onPortfolioUpdated: onPortfolioUpdated,
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

  // Portfolio mode & IBKR state
  String _portfolioMode = 'demo';
  IBKRConfig? _ibkrConfig;
  final _flexTokenCtrl = TextEditingController();
  final _queryIdCtrl = TextEditingController();
  bool _obscureToken = true;
  bool _isSavingIBKR = false;
  bool _isSyncingIBKR = false;

  // Admin stats
  AdminStats? _adminStats;
  bool _isLoadingAdmin = false;

  @override
  void initState() {
    super.initState();
    SessionStore.readEmail().then((v) {
      if (mounted) {
        setState(() => _email = v);
        if (SessionStore.isAdmin(v)) {
          _loadAdminStats();
        }
      }
    });
    SessionStore.isBiometricsEnabled().then((v) {
      if (mounted) setState(() => _biometricsEnabled = v);
    });
    _loadPortfolioMode();
    _loadIBKRConfig();
  }

  Future<void> _loadPortfolioMode() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/portfolio/mode'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted && data['mode'] != null) {
          setState(() => _portfolioMode = data['mode']);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadIBKRConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localSavedToken = prefs.getString('ibkr_saved_token') ?? '';
      final localSavedQueryId = prefs.getString('ibkr_saved_query_id') ?? '';

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/ibkr/config'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final cfg = IBKRConfig.fromJson(data);
        if (mounted) {
          setState(() {
            _ibkrConfig = cfg;

            final effectiveQueryId = cfg.queryId.isNotEmpty
                ? cfg.queryId
                : (localSavedQueryId.isNotEmpty ? localSavedQueryId : IBKRDefaults.defaultQueryId);
            _queryIdCtrl.text = effectiveQueryId;
            prefs.setString('ibkr_saved_query_id', effectiveQueryId);

            final effectiveToken = cfg.token.isNotEmpty
                ? cfg.token
                : (localSavedToken.isNotEmpty ? localSavedToken : IBKRDefaults.defaultToken);
            _flexTokenCtrl.text = effectiveToken;
            prefs.setString('ibkr_saved_token', effectiveToken);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            final effectiveQueryId = localSavedQueryId.isNotEmpty ? localSavedQueryId : IBKRDefaults.defaultQueryId;
            _queryIdCtrl.text = effectiveQueryId;
            final effectiveToken = localSavedToken.isNotEmpty ? localSavedToken : IBKRDefaults.defaultToken;
            _flexTokenCtrl.text = effectiveToken;
          });
        }
      }
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final localSavedToken = prefs.getString('ibkr_saved_token') ?? '';
        final localSavedQueryId = prefs.getString('ibkr_saved_query_id') ?? '';
        if (mounted) {
          setState(() {
            final effectiveQueryId = localSavedQueryId.isNotEmpty ? localSavedQueryId : IBKRDefaults.defaultQueryId;
            _queryIdCtrl.text = effectiveQueryId;
            final effectiveToken = localSavedToken.isNotEmpty ? localSavedToken : IBKRDefaults.defaultToken;
            _flexTokenCtrl.text = effectiveToken;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadAdminStats() async {
    setState(() => _isLoadingAdmin = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/users'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (mounted) {
          setState(() {
            _adminStats = AdminStats.fromJson(data);
            _isLoadingAdmin = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAdmin = false);
    }
  }

  Future<void> _switchPortfolioMode(String targetMode) async {
    if (targetMode == _portfolioMode) return;

    final bool isGoingToReal = targetMode == 'real';

    if (isGoingToReal && (_ibkrConfig?.configured != true)) {
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
            'Щоб бачити дані реального рахунку, ви можете ввести числовий токен Flex Query, або скористатися миттєвим тестовим демо-підключенням з живими біржовими котируваннями.',
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
        _fillDemoIBKR();
        // after demo fills, switch mode
        targetMode = 'real';
      } else if (choice == 'input') {
        // focus or stay on IBKR settings
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
              isGoingToReal ? Icons.warning_amber_rounded : Icons.sports_esports_rounded,
              color: isGoingToReal ? const Color(0xFFFFB74D) : const Color(0xFF00FF94),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isGoingToReal ? 'Перехід у РЕАЛЬНИЙ режим' : 'Повернення у ДЕМО-режим',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isGoingToReal
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
              backgroundColor: isGoingToReal ? const Color(0xFFFFB74D) : const Color(0xFF00FF94),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isGoingToReal ? 'Так, увімкнути IBKR' : 'Так, перейти у Демо',
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
        body: jsonEncode({'mode': targetMode}),
      );
      if (res.statusCode == 200) {
        setState(() => _portfolioMode = targetMode);
        widget.onPortfolioUpdated?.call();
        if (isGoingToReal && (_ibkrConfig?.configured == true)) {
          _syncIBKRNow();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: isGoingToReal ? const Color(0xFF00FF94) : const Color(0xFF00E5FF),
              content: Text(
                isGoingToReal
                    ? '🟢 Режим змінено: Реальні дані (Interactive Brokers)'
                    : '🎮 Режим змінено: Демо-симулятор',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      } else {
        throw Exception(res.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Помилка зміни режиму: $e')),
        );
      }
    }
  }
  Future<void> _saveIBKRConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final localSavedToken = prefs.getString('ibkr_saved_token') ?? '';
    final localSavedQueryId = prefs.getString('ibkr_saved_query_id') ?? '';

    String token = _flexTokenCtrl.text.trim();
    String queryId = _queryIdCtrl.text.trim();

    if (queryId.isEmpty) {
      queryId = localSavedQueryId.isNotEmpty ? localSavedQueryId : IBKRDefaults.defaultQueryId;
      _queryIdCtrl.text = queryId;
    }
    if (token.isEmpty || token.contains('*')) {
      token = localSavedToken.isNotEmpty ? localSavedToken : IBKRDefaults.defaultToken;
      _flexTokenCtrl.text = token;
    }

    setState(() => _isSavingIBKR = true);
    try {
      if (token.isNotEmpty && !token.contains('*') && token != 'DEMO_IBKR') {
        await prefs.setString('ibkr_saved_token', token);
      }
      if (queryId.isNotEmpty && queryId != 'DEMO') {
        await prefs.setString('ibkr_saved_query_id', queryId);
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/ibkr/config'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'flex_token': token, 'query_id': queryId}),
      );

      IBKRResult result;
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        result = IBKRResult.fromJson(body);
      } catch (_) {
        result = IBKRResult(
          isSuccess: res.statusCode == 200,
          status: res.statusCode == 200 ? 'ok' : 'error',
          accountId: _ibkrConfig?.accountId ?? '',
          positionsCount: 0,
          cash: 0,
          friendlyMessage: utf8.decode(res.bodyBytes),
          errorMessage: utf8.decode(res.bodyBytes),
        );
      }

      await _loadIBKRConfig();
      widget.onPortfolioUpdated?.call();

      if (mounted) {
        IBKRConnectionResultDialog.show(
          context,
          result: result,
          isAdmin: SessionStore.isAdmin(_email),
          onRetry: _saveIBKRConfig,
          onOpenGuide: _showIBKRGuideDialog,
          onTryDemo: _fillDemoIBKR,
        );
      }
    } catch (e) {
      if (mounted) {
        final errResult = IBKRResult(
          isSuccess: false,
          status: 'error',
          accountId: _ibkrConfig?.accountId ?? '',
          positionsCount: 0,
          cash: 0,
          friendlyMessage: 'Помилка збереження IBKR: ${e.toString().replaceAll("Exception: ", "")}',
          errorMessage: e.toString(),
        );
        IBKRConnectionResultDialog.show(
          context,
          result: errResult,
          isAdmin: SessionStore.isAdmin(_email),
          onRetry: _saveIBKRConfig,
          onOpenGuide: _showIBKRGuideDialog,
          onTryDemo: _fillDemoIBKR,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingIBKR = false);
    }
  }

  Future<void> _syncIBKRNow() async {
    setState(() => _isSyncingIBKR = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/ibkr/sync'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      IBKRResult result;
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        result = IBKRResult.fromJson(body);
      } catch (_) {
        result = IBKRResult(
          isSuccess: res.statusCode == 200,
          status: res.statusCode == 200 ? 'ok' : 'error',
          accountId: _ibkrConfig?.accountId ?? '',
          positionsCount: 0,
          cash: 0,
          friendlyMessage: utf8.decode(res.bodyBytes),
          errorMessage: utf8.decode(res.bodyBytes),
        );
      }

      await _loadIBKRConfig();
      widget.onPortfolioUpdated?.call();

      if (mounted) {
        IBKRConnectionResultDialog.show(
          context,
          result: result,
          isAdmin: SessionStore.isAdmin(_email),
          onRetry: _syncIBKRNow,
          onOpenGuide: _showIBKRGuideDialog,
          onTryDemo: _fillDemoIBKR,
        );
      }
    } catch (e) {
      if (mounted) {
        final errResult = IBKRResult(
          isSuccess: false,
          status: 'error',
          accountId: _ibkrConfig?.accountId ?? '',
          positionsCount: 0,
          cash: 0,
          friendlyMessage: 'Помилка синхронізації IBKR: ${e.toString().replaceAll("Exception: ", "")}',
          errorMessage: e.toString(),
        );
        IBKRConnectionResultDialog.show(
          context,
          result: errResult,
          isAdmin: SessionStore.isAdmin(_email),
          onRetry: _syncIBKRNow,
          onOpenGuide: _showIBKRGuideDialog,
          onTryDemo: _fillDemoIBKR,
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingIBKR = false);
    }
  }

  void _fillDemoIBKR() {
    _flexTokenCtrl.text = 'DEMO_IBKR';
    _queryIdCtrl.text = 'DEMO';
    _saveIBKRConfig();
  }

  void _showIBKRGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('Як підключити IBKR?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Для безпечної синхронізації у режимі лише для читання (Read-Only) через IBKR Flex Web Service:\n\n'
                '1️⃣ Увійдіть в IBKR Client Portal (interactivebrokers.com).\n'
                '2️⃣ Перейдіть у розділ: «Performance & Reports» ➔ «Flex Queries».\n'
                '3️⃣ У блоці «Flex Web Service Configuration» активуйте сервіс та згенеруйте поточний токен (Current Token).\n'
                '4️⃣ Створіть новий звіт (Activity Flex Query або Positions Flex Query):\n'
                '   • Обовʼязково увімкніть секцію «Open Positions» та «Cash Report».\n'
                '   • Збережіть звіт та скопіюйте цифровий «Query ID» (наприклад, 123456).\n'
                '5️⃣ Введіть отримані Token та Query ID тут і натисніть «Зберегти та синхронізувати».\n\n'
                '🔒 Безпека: Flex Web Service надає виключно звіти про баланси і активи та не має права відкривати/закривати угоди чи виводити кошти.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Зрозуміло', style: TextStyle(color: Color(0xFF00FF94)))),
        ],
      ),
    );
  }

  void _showAdminUsersSheet() {
    AdminUsersSheet.show(context, token: widget.token);
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
            if (SessionStore.isAdmin(_email)) ...[
              const SizedBox(height: 14),
              _buildAdminCard(),
            ],
            const SizedBox(height: 14),
            _buildModeSwitcherCard(),
            const SizedBox(height: 14),
            _buildIBKRCard(),
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

  Widget _buildAdminCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFD700), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('АДМІНІСТРАТИВНА ПАНЕЛЬ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                    Text('Статистика активності та користувачів', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: _isLoadingAdmin
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)))
                    : const Icon(Icons.refresh_rounded, color: Color(0xFFFFD700), size: 20),
                onPressed: _loadAdminStats,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_adminStats != null) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('Всього юзерів', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('${_adminStats!.totalUsers}', style: const TextStyle(color: Color(0xFF00FF94), fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('Онлайн 24г', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('${_adminStats!.activeToday}', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('За 7 днів', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('${_adminStats!.active7d}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD700),
                side: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.people_outline_rounded, size: 18),
              label: const Text('Список користувачів та активність', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _showAdminUsersSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcherCard() {
    final bool isReal = _portfolioMode == 'real';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReal ? const Color(0xFF00FF94).withValues(alpha: 0.3) : const Color(0xFF00E5FF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReal ? Icons.verified_user_rounded : Icons.sports_esports_rounded,
                color: isReal ? const Color(0xFF00FF94) : const Color(0xFF00E5FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('РЕЖИМ ДАНИХ ПОРТФЕЛЯ', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReal ? const Color(0xFF00FF94).withValues(alpha: 0.15) : const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isReal ? '🟢 РЕАЛЬНИЙ IBKR' : '🎮 ДЕМО-СИМУЛЯТОР',
                  style: TextStyle(
                    color: isReal ? const Color(0xFF00FF94) : const Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isReal
                ? 'Зараз відображаються реальні активи вашого рахунку Interactive Brokers.'
                : 'Зараз увімкнено симулятор з віртуальним балансом для безпечного тренування.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: !isReal ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.08),
                    foregroundColor: !isReal ? Colors.black : Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.sports_esports_rounded, size: 16),
                  label: const Text('Демо-режим', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _switchPortfolioMode('demo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isReal ? const Color(0xFF00FF94) : Colors.white.withValues(alpha: 0.08),
                    foregroundColor: isReal ? Colors.black : Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.account_balance_rounded, size: 16),
                  label: const Text('Реальний IBKR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _switchPortfolioMode('real'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIBKRCard() {
    final bool isConfigured = _ibkrConfig?.configured ?? false;
    final String lastSync = _ibkrConfig?.lastSyncAt ?? '';
    final String syncStatus = _ibkrConfig?.syncStatus ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Color(0xFF00E5FF), size: 20),
                  SizedBox(width: 8),
                  Text('ІНТЕГРАЦІЯ З IBKR (FLEX QUERY)', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF00E5FF), size: 18),
                tooltip: 'Інструкція налаштування',
                onPressed: _showIBKRGuideDialog,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isConfigured
                  ? (syncStatus == 'error' ? Colors.redAccent.withValues(alpha: 0.1) : const Color(0xFF00FF94).withValues(alpha: 0.1))
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isConfigured
                      ? (syncStatus == 'error' ? Icons.error_outline_rounded : Icons.check_circle_rounded)
                      : Icons.cloud_off_rounded,
                  size: 16,
                  color: isConfigured
                      ? (syncStatus == 'error' ? Colors.redAccent : const Color(0xFF00FF94))
                      : Colors.white38,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConfigured
                        ? (syncStatus == 'error'
                            ? 'Помилка оновлення: ${_ibkrConfig?.errorMessage ?? ""}'
                            : 'Підключено: ${_ibkrConfig?.accountId.isNotEmpty == true ? _ibkrConfig!.accountId : "Рахунок IBKR"} (${lastSync.isNotEmpty ? lastSync : "щойно"})')
                        : 'Flex Web Service ще не налаштовано',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isConfigured
                          ? (syncStatus == 'error' ? Colors.redAccent : const Color(0xFF00FF94))
                          : Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _flexTokenCtrl,
            obscureText: _obscureToken,
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: isConfigured ? 'Flex Token (Збережено: ${_ibkrConfig?.tokenMasked})' : 'Flex Query Token (тільки цифри)',
              hintText: 'Введіть числовий токен з IBKR',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: Icon(_obscureToken ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                onPressed: () => setState(() => _obscureToken = !_obscureToken),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _queryIdCtrl,
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Query ID звіту (тільки цифри)',
              hintText: 'Напр. 987654',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSavingIBKR ? null : _saveIBKRConfig,
                  child: _isSavingIBKR
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Зберегти та Синхронізувати', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              if (isConfigured) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF94).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF00FF94),
                  ),
                  tooltip: 'Синхронізувати зараз',
                  icon: _isSyncingIBKR
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF94)))
                      : const Icon(Icons.sync_rounded),
                  onPressed: _isSyncingIBKR ? null : _syncIBKRNow,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 14, color: Color(0xFF00FF94)),
              label: const Text('Тестове підключення (Demo IBKR)', style: TextStyle(color: Color(0xFF00FF94), fontSize: 11)),
              onPressed: _fillDemoIBKR,
            ),
          ),
        ],
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

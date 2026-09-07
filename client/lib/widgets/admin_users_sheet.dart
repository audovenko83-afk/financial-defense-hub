import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/models.dart';

class AdminUsersSheet extends StatefulWidget {
  final String token;

  const AdminUsersSheet({super.key, required this.token});

  static void show(BuildContext context, {required String token}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminUsersSheet(token: token),
    );
  }

  @override
  State<AdminUsersSheet> createState() => _AdminUsersSheetState();
}

class _AdminUsersSheetState extends State<AdminUsersSheet> {
  int _selectedTab = 0; // 0: Users, 1: IBKR Audit Logs
  AdminStats? _stats;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  List<AdminAuditLog>? _auditLogs;
  bool _isLoadingLogs = false;
  String? _logsError;
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchAuditLogs();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/users'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _stats = AdminStats.fromJson(data);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Помилка доступу (${res.statusCode}): ${res.body}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не вдалося завантажити дані: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAuditLogs() async {
    setState(() {
      _isLoadingLogs = true;
      _logsError = null;
    });
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/admin/audit-logs?status=$_statusFilter');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final rawList = data['logs'] as List? ?? [];
        final logs = rawList.map((l) => AdminAuditLog.fromJson(l as Map<String, dynamic>)).toList();
        if (mounted) {
          setState(() {
            _auditLogs = logs;
            _isLoadingLogs = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _logsError = 'Помилка отримання журналу: ${res.statusCode}';
            _isLoadingLogs = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logsError = 'Не вдалося завантажити журнал: $e';
          _isLoadingLogs = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _stats?.users.where((u) {
          if (_searchQuery.isEmpty) return true;
          return u.email.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList() ??
        [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF131722),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 12, left: 18, right: 18, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFD700), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Адміністративна панель',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFFFD700)),
                    ),
                    Text(
                      'Користувачі та системний журнал IBKR',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: () {
                  if (_selectedTab == 0) {
                    _fetchUsers();
                  } else {
                    _fetchAuditLogs();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 0),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? const Color(0xFFFFD700) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '👥 Користувачі',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 0 ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? const Color(0xFFFFD700) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '📜 Журнал IBKR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 1 ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedTab == 0) ...[
          if (_isLoading) ...[
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
            ),
          ] else if (_error != null) ...[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      const SizedBox(height: 14),
                      ElevatedButton(onPressed: _fetchUsers, child: const Text('Спробувати знову')),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_stats != null) ...[
            Row(
              children: [
                _buildStatPill('Всього', '${_stats!.totalUsers}', Icons.people_alt_rounded, const Color(0xFF00FF94)),
                const SizedBox(width: 8),
                _buildStatPill('Сьогодні', '${_stats!.activeToday}', Icons.bolt_rounded, const Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                _buildStatPill('За 7 днів', '${_stats!.active7d}', Icons.calendar_today_rounded, const Color(0xFFFFD700)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Пошук за email...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.white38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: const Color(0xFF1A1F2C),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredUsers.isEmpty
                  ? const Center(child: Text('Користувачів не знайдено', style: TextStyle(color: Colors.white38)))
                  : RefreshIndicator(
                      color: const Color(0xFFFFD700),
                      onRefresh: _fetchUsers,
                      child: ListView.separated(
                        itemCount: filteredUsers.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _buildUserCard(filteredUsers[i]),
                      ),
                    ),
            ),
          ],
        ] else ...[
          _buildAuditLogsView(),
        ],
        ],
      ),
    );
  }
  Widget _buildAuditLogsView() {
    if (_isLoadingLogs) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }
    if (_logsError != null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
              const SizedBox(height: 10),
              Text(_logsError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchAuditLogs, child: const Text('Спробувати знову')),
            ],
          ),
        ),
      );
    }
    final logs = _auditLogs ?? [];
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Усі події', 'ALL'),
                const SizedBox(width: 6),
                _buildFilterChip('⚠️ Помилки', 'ERROR'),
                const SizedBox(width: 6),
                _buildFilterChip('🟢 Успішні', 'SUCCESS'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('Записів у журналі немає', style: TextStyle(color: Colors.white38)))
                : RefreshIndicator(
                    color: const Color(0xFFFFD700),
                    onRefresh: _fetchAuditLogs,
                    child: ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _buildAuditLogCard(logs[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.black : Colors.white70)),
      selected: isSelected,
      selectedColor: const Color(0xFFFFD700),
      backgroundColor: const Color(0xFF1A1F2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _fetchAuditLogs();
      },
    );
  }

  Widget _buildAuditLogCard(AdminAuditLog log) {
    final isSuccess = log.status == 'SUCCESS';
    final isError = log.status == 'ERROR';
    final statusColor = isSuccess ? const Color(0xFF00FF94) : (isError ? Colors.redAccent : const Color(0xFFFFB74D));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  log.status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  log.eventType,
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Text(
                log.friendlyCreatedAt,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 13, color: Colors.white54),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  log.userEmail.isNotEmpty ? log.userEmail : log.userId,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (log.durationMs > 0)
                Text('${log.durationMs} мс', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          if (log.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(log.message, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
          if (log.errorCode.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Код помилки: ${log.errorCode}', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
          if (log.queryId.isNotEmpty || log.accountId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Query: ${log.queryId.isNotEmpty ? log.queryId : "—"} • Рахунок: ${log.accountId.isNotEmpty ? log.accountId : "—"} • Токен: ${log.tokenMasked.isNotEmpty ? log.tokenMasked : "—"}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
          if (log.details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                log.details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildStatPill(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(AdminUserInfo user) {
    final bool isAdmin = SessionStore.isAdmin(user.email);
    final bool isGoogle = user.provider.toLowerCase() == 'google';
    final bool isGithub = user.provider.toLowerCase() == 'github';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdmin ? const Color(0xFFFFD700).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: isAdmin
                ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                : (isGoogle
                    ? const Color(0xFF4285F4).withValues(alpha: 0.18)
                    : isGithub
                        ? Colors.white.withValues(alpha: 0.15)
                        : const Color(0xFF00FF94).withValues(alpha: 0.15)),
            child: Icon(
              isAdmin
                  ? Icons.shield_rounded
                  : (isGoogle
                      ? Icons.g_mobiledata_rounded
                      : isGithub
                          ? Icons.code_rounded
                          : Icons.person_rounded),
              color: isAdmin
                  ? const Color(0xFFFFD700)
                  : (isGoogle
                      ? const Color(0xFF4285F4)
                      : isGithub
                          ? Colors.white
                          : const Color(0xFF00FF94)),
              size: 22,
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
                        user.email,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ADMIN', style: TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF94).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_filled_rounded, size: 12, color: Color(0xFF00FF94)),
                      const SizedBox(width: 5),
                      Text(
                        'Був у застосунку: ${user.friendlyLastSeen}',
                        style: const TextStyle(color: Color(0xFF00FF94), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Реєстрація: ${user.friendlyCreatedAt} • ${user.provider.toUpperCase()}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: user.portfolioMode == 'real' ? const Color(0xFF00FF94).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.portfolioMode == 'real' ? '🟢 IBKR Реал' : '🎮 Демо',
                        style: TextStyle(
                          color: user.portfolioMode == 'real' ? const Color(0xFF00FF94) : Colors.white54,
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
        ],
      ),
    );
  }

}

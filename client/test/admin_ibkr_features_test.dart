import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/models.dart';

void main() {
  group('Admin & IBKR Models Test', () {
    test('PortfolioData parses mode and IBKR fields', () {
      final json = {
        'mode': 'real',
        'total_value': 25400.5,
        'cash': 3200.0,
        'invested_value': 22200.5,
        'total_dividends': 150.0,
        'total_pnl': 1200.0,
        'total_pnl_percent': 5.4,
        'positions': [
          {
            'ticker': 'AAPL',
            'company_name': 'Apple Inc.',
            'asset_class': 'Stock',
            'shares': 10.0,
            'average_buy_price': 180.0,
            'current_price': 220.0,
            'total_value': 2200.0,
            'unrealized_pnl': 400.0,
            'unrealized_pnl_percent': 22.2,
            'currency': 'USD',
          }
        ],
        'dividends': [],
        'ibkr_configured': true,
        'ibkr_last_sync_at': '2026-09-07 10:00:00',
        'ibkr_account_id': 'U1234567',
      };

      final data = PortfolioData.fromJson(json);
      expect(data.mode, 'real');
      expect(data.ibkrConfigured, true);
      expect(data.ibkrAccountId, 'U1234567');
      expect(data.positions.length, 1);
      expect(data.positions.first.ticker, 'AAPL');
    });

    test('AdminUserInfo friendlyLastSeen relative time formats correctly', () {
      final now = DateTime.now().toUtc();

      final justNow = AdminUserInfo(
        id: '1',
        email: 'user1@test.com',
        provider: 'google',
        createdAt: now.toIso8601String(),
        lastSeenAt: now.subtract(const Duration(seconds: 20)).toIso8601String(),
        portfolioMode: 'demo',
        totalValue: 10000,
      );
      expect(justNow.friendlyLastSeen, 'Тільки що онлайн');

      final minutesAgo = AdminUserInfo(
        id: '2',
        email: 'user2@test.com',
        provider: 'email',
        createdAt: now.toIso8601String(),
        lastSeenAt: now.subtract(const Duration(minutes: 25)).toIso8601String(),
        portfolioMode: 'real',
        totalValue: 15000,
      );
      expect(minutesAgo.friendlyLastSeen, '25 хв тому');

      final hoursAgo = AdminUserInfo(
        id: '3',
        email: 'user3@test.com',
        provider: 'github',
        createdAt: now.toIso8601String(),
        lastSeenAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
        portfolioMode: 'demo',
        totalValue: 5000,
      );
      expect(hoursAgo.friendlyLastSeen, '3 год тому');

      final yesterday = AdminUserInfo(
        id: '4',
        email: 'user4@test.com',
        provider: 'email',
        createdAt: now.toIso8601String(),
        lastSeenAt: now.subtract(const Duration(days: 1)).toIso8601String(),
        portfolioMode: 'demo',
        totalValue: 0,
      );
      expect(yesterday.friendlyLastSeen, 'Вчора');

      final daysAgo = AdminUserInfo(
        id: '5',
        email: 'user5@test.com',
        provider: 'google',
        createdAt: now.toIso8601String(),
        lastSeenAt: now.subtract(const Duration(days: 4)).toIso8601String(),
        portfolioMode: 'real',
        totalValue: 12000,
      );
      expect(daysAgo.friendlyLastSeen, '4 дн. тому');
    });

    test('IBKRConfig parses JSON correctly', () {
      final json = {
        'configured': true,
        'query_id': '987654',
        'token_masked': '****1234',
        'last_sync_at': '2026-09-07 11:30:00',
        'sync_status': 'success',
        'error_message': '',
        'account_id': 'U9999999',
        'mode': 'real',
      };

      final cfg = IBKRConfig.fromJson(json);
      expect(cfg.configured, true);
      expect(cfg.queryId, '987654');
      expect(cfg.tokenMasked, '****1234');
      expect(cfg.syncStatus, 'success');
      expect(cfg.accountId, 'U9999999');
      expect(cfg.mode, 'real');
    });
  });
}

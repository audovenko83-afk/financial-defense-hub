import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/models.dart';
import 'package:client/widgets/ibkr_connection_result_dialog.dart';

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
    test('IBKRResult parses success and error payloads', () {
      final successJson = {
        'status': 'ok',
        'account_id': 'U12345678',
        'positions_count': 5,
        'cash': 3450.0,
        'friendly_message': 'Рахунок IBKR успішно підключено та синхронізовано!',
        'duration_ms': 1200,
        'is_demo': false,
      };
      final success = IBKRResult.fromJson(successJson);
      expect(success.isSuccess, true);
      expect(success.accountId, 'U12345678');
      expect(success.positionsCount, 5);
      expect(success.cash, 3450.0);
      expect(success.durationMs, 1200);

      final errorJson = {
        'status': 'error',
        'error_code': '1014',
        'friendly_message': 'Термін дії токена Flex Query закінчився.',
        'error_message': 'Flex query expired',
        'raw_details': '<ErrorCode>1014</ErrorCode>',
        'duration_ms': 450,
      };
      final err = IBKRResult.fromJson(errorJson);
      expect(err.isSuccess, false);
      expect(err.errorCode, '1014');
      expect(err.friendlyMessage, 'Термін дії токена Flex Query закінчився.');
      expect(err.errorMessage, 'Flex query expired');
      expect(err.durationMs, 450);
    });

    test('AdminAuditLog parses JSON and formats friendly date', () {
      final logJson = {
        'id': 1,
        'user_id': 'usr-123',
        'user_email': 'test@gmail.com',
        'event_type': 'IBKR_SYNC',
        'status': 'SUCCESS',
        'account_id': 'U9876543',
        'query_id': '123456',
        'token_masked': '****4321',
        'error_code': '',
        'message': 'Синхронізовано 5 позицій',
        'details': 'Query: Positions, Cash: 3450',
        'duration_ms': 850,
        'ip_address': '127.0.0.1',
        'created_at': '2026-09-07T14:30:00Z',
      };
      final log = AdminAuditLog.fromJson(logJson);
      expect(log.id, 1);
      expect(log.userEmail, 'test@gmail.com');
      expect(log.eventType, 'IBKR_SYNC');
      expect(log.status, 'SUCCESS');
      expect(log.durationMs, 850);
      expect(log.friendlyCreatedAt, isNotEmpty);
    });

  });

  group('IBKRConnectionResultDialog Widget Tests', () {
    testWidgets('Renders success dialog with account and cash details', (tester) async {
      final successResult = IBKRResult(
        isSuccess: true,
        status: 'ok',
        accountId: 'U99988877',
        positionsCount: 4,
        cash: 5200.0,
        friendlyMessage: 'Рахунок IBKR успішно підключено та синхронізовано!',
        durationMs: 950,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IBKRConnectionResultDialog(
              result: successResult,
              isAdmin: false,
            ),
          ),
        ),
      );

      expect(find.text('Зʼєднання з IBKR встановлено!'), findsOneWidget);
      expect(find.text('Рахунок IBKR успішно підключено та синхронізовано!'), findsOneWidget);
      expect(find.text('U99988877'), findsOneWidget);
      expect(find.text('\$5200.00'), findsOneWidget);
      expect(find.text('4 поз.'), findsOneWidget);
      expect(find.text('Перейти до портфеля'), findsOneWidget);
    });

    testWidgets('Renders error dialog with tips and admin details', (tester) async {
      final errorResult = IBKRResult(
        isSuccess: false,
        status: 'error',
        accountId: '',
        positionsCount: 0,
        cash: 0,
        friendlyMessage: 'Невірний цифровий токен Flex Query.',
        errorCode: '1015',
        errorMessage: 'Invalid token',
        rawDetails: '<ErrorCode>1015</ErrorCode>',
        durationMs: 320,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IBKRConnectionResultDialog(
              result: errorResult,
              isAdmin: true,
            ),
          ),
        ),
      );

      expect(find.text('Не вдалося підключитися до IBKR'), findsOneWidget);
      expect(find.text('Невірний цифровий токен Flex Query.'), findsOneWidget);
      expect(find.text('Що потрібно перевірити:'), findsOneWidget);
      expect(find.text('Звіт для адміністратора (Журнал подій)'), findsOneWidget);

      // Tap on admin section to expand
      await tester.tap(find.text('Звіт для адміністратора (Журнал подій)'));
      await tester.pumpAndSettle();

      expect(find.text('Код помилки IBKR: 1015'), findsOneWidget);
      expect(find.text('Тривалість: 320 мс'), findsOneWidget);
    });

  });
}

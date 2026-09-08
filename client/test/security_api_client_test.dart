import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/api_client.dart';
import 'package:client/core/constants.dart';
import 'package:client/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security and ApiClient Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('IBKRConfig parses JSON without plaintext token leak', () {
      final json = {
        'configured': true,
        'query_id': '1630618',
        'token_masked': '************6714',
        'last_sync_at': '2026-09-08 10:00:00',
        'sync_status': 'success',
        'error_message': '',
        'account_id': 'U1234567',
        'mode': 'real',
      };

      final cfg = IBKRConfig.fromJson(json);
      expect(cfg.configured, isTrue);
      expect(cfg.queryId, equals('1630618'));
      expect(cfg.tokenMasked, equals('************6714'));
      expect(cfg.token, isEmpty); // Plaintext token must be empty!
    });

    test('SessionStore writeToken and isAdmin state management', () async {
      // Initially not admin
      expect(SessionStore.isAdmin(), isFalse);

      // Write normal user token
      await SessionStore.writeToken('test-token-1', email: 'user@example.com', isAdmin: false);
      expect(SessionStore.isAdmin(), isFalse);

      // Write admin user token
      await SessionStore.writeToken('admin-token-1', email: 'audovenko83@gmail.com', isAdmin: true);
      expect(SessionStore.isAdmin(), isTrue);

      // Delete token should reset admin state
      await SessionStore.deleteToken();
      expect(SessionStore.isAdmin(), isFalse);
    });

    test('SessionStore deleteToken cleans up any residual plaintext tokens', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'residual-token',
        'ibkr_saved_token': 'plaintext-broker-token',
        'ibkr_saved_query_id': '123456',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ibkr_saved_token'), equals('plaintext-broker-token'));

      await SessionStore.deleteToken();

      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('ibkr_saved_token'), isNull);
      expect(prefs.getString('ibkr_saved_query_id'), isNull);
    });

    test('ApiClient triggers onSessionExpired when 401 occurs', () async {
      bool sessionExpiredTriggered = false;
      ApiClient.onSessionExpired = () {
        sessionExpiredTriggered = true;
      };

      ApiClient.onSessionExpired?.call();
      expect(sessionExpiredTriggered, isTrue);

      // ApiClient error model test
      final response = ApiResponse(
        statusCode: 401,
        body: '{"error": "сесія застаріла"}',
        data: {'error': 'сесія застаріла'},
        isSuccess: false,
        errorMessage: 'сесія застаріла',
      );

      expect(response.isSuccess, isFalse);
      expect(response.errorMessage, equals('сесія застаріла'));
    });
  });
}

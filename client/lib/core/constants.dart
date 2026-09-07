import 'package:shared_preferences/shared_preferences.dart';

class AppStrings {
  static const appTitle = 'Фінансовий Захист';
  static const appSubtitle = 'Шлях до \$1 000 000';
  static const portfolioTitle = 'Мій портфель';
  static const totalValueLabel = 'ЗАГАЛЬНА ВАРТІСТЬ ПОРТФЕЛЯ';
  static const cashLabel = 'ВІЛЬНИЙ КЕШ';
  static const assetsLabel = 'АКТИВНІ ПОЗИЦІЇ (РЕАЛЬНИЙ РИНОК)';
  static const buyAction = 'КУПИТИ';
  static const sellAction = 'ПРОДАТИ';
  static const depositAction = 'ПОПОВНИТИ КЕШ';
  static const transactionTitle = 'Купити активи';
  static const tickerHint = 'Тікер активу (напр. AAPL, VOO, TSLA)';
  static const assetTypeHint = 'Клас активу';
  static const quantityHint = 'Кількість одиниць';
  static const priceHint = 'Ціна за одиницю (\$)';
  static const savePurchase = 'Купити акції';
  static const transactionHistory = 'Історія операцій';
  static const investedLabel = 'ВКЛАДЕНО';
  static const dividendsLabel = 'ДИВІДЕНДИ';
  static const recentDividendsLabel = 'ОСТАННІ ДИВІДЕНДИ';
  static const noDividends = 'Дивідендів ще немає';
  static const timeMachine = 'Машина часу';
  static const simulate = 'РОЗРАХУВАТИ СЦЕНАРІЇ';
}

class ApiConfig {
  static const String _envUrl = String.fromEnvironment('API_URL');
  static const String _urlKey = 'custom_api_url';
  static String? _customUrl;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_urlKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _customUrl = saved.trim();
      }
    } catch (_) {}
  }

  static String get baseUrl {
    if (_customUrl != null && _customUrl!.isNotEmpty) {
      return _customUrl!;
    }
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    return 'http://127.0.0.1:8080/api';
  }

  static Future<void> setBaseUrl(String url) async {
    _customUrl = url.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlKey, _customUrl!);
    } catch (_) {}
  }
}

class SessionStore {
  static const _tokenKey = 'auth_token';
  static const _emailKey = 'user_email';

  static Future<String?> readToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeToken(String token, {String? email}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      if (email != null) {
        await prefs.setString(_emailKey, email);
      }
    } catch (_) {}
  }

  static Future<String?> readEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_emailKey);
    } catch (_) {}
  }
}

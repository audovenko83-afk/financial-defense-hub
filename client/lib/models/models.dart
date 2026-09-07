class Position {
  final String ticker;
  final String companyName;
  final String assetClass;
  final double shares;
  final double averageBuyPrice;
  final double currentPrice;
  final double totalValue;
  final double unrealizedPnL;
  final double unrealizedPnLPercent;
  final double dayChangePercent;
  final String currency;

  Position({
    required this.ticker,
    required this.companyName,
    required this.assetClass,
    required this.shares,
    required this.averageBuyPrice,
    required this.currentPrice,
    required this.totalValue,
    required this.unrealizedPnL,
    required this.unrealizedPnLPercent,
    required this.dayChangePercent,
    required this.currency,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      ticker: json['ticker'] ?? '',
      companyName: json['company_name'] ?? '',
      assetClass: json['asset_class'] ?? 'Stock',
      shares: (json['shares'] as num?)?.toDouble() ?? 0.0,
      averageBuyPrice: (json['average_buy_price'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
      unrealizedPnL: (json['unrealized_pnl'] as num?)?.toDouble() ?? 0.0,
      unrealizedPnLPercent: (json['unrealized_pnl_percent'] as num?)?.toDouble() ?? 0.0,
      dayChangePercent: (json['day_change_percent'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
    );
  }
}

class Dividend {
  final int id;
  final String ticker;
  final double amount;
  final String currency;
  final String paidAt;

  Dividend({
    required this.id,
    required this.ticker,
    required this.amount,
    required this.currency,
    required this.paidAt,
  });

  factory Dividend.fromJson(Map<String, dynamic> json) {
    return Dividend(
      id: json['id'] ?? 0,
      ticker: json['ticker'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      paidAt: json['paid_at'] ?? '',
    );
  }
}

class PortfolioData {
  final String mode; // 'demo' | 'real'
  final double totalValue;
  final double cash;
  final double investedValue;
  final double totalDividends;
  final double totalPnL;
  final double totalPnLPercent;
  final List<Position> positions;
  final List<Dividend> dividends;
  final bool ibkrConfigured;
  final String? ibkrLastSyncAt;
  final String? ibkrAccountId;

  PortfolioData({
    this.mode = 'demo',
    required this.totalValue,
    required this.cash,
    required this.investedValue,
    required this.totalDividends,
    required this.totalPnL,
    required this.totalPnLPercent,
    required this.positions,
    required this.dividends,
    this.ibkrConfigured = false,
    this.ibkrLastSyncAt,
    this.ibkrAccountId,
  });

  factory PortfolioData.fromJson(Map<String, dynamic> json) {
    final posList = (json['positions'] as List?)
            ?.map((p) => Position.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];
    final divList = (json['dividends'] as List?)
            ?.map((d) => Dividend.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];
    return PortfolioData(
      mode: json['mode'] as String? ?? 'demo',
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
      cash: (json['cash'] as num?)?.toDouble() ?? 0.0,
      investedValue: (json['invested_value'] as num?)?.toDouble() ?? 0.0,
      totalDividends: (json['total_dividends'] as num?)?.toDouble() ?? 0.0,
      totalPnL: (json['total_pnl'] as num?)?.toDouble() ?? 0.0,
      totalPnLPercent: (json['total_pnl_percent'] as num?)?.toDouble() ?? 0.0,
      positions: posList,
      dividends: divList,
      ibkrConfigured: json['ibkr_configured'] as bool? ?? false,
      ibkrLastSyncAt: json['ibkr_last_sync_at'] as String?,
      ibkrAccountId: json['ibkr_account_id'] as String?,
    );
  }
}

class AdminUserInfo {
  final String id;
  final String email;
  final String provider;
  final String createdAt;
  final String lastSeenAt;
  final String portfolioMode;
  final double totalValue;

  AdminUserInfo({
    required this.id,
    required this.email,
    required this.provider,
    required this.createdAt,
    required this.lastSeenAt,
    required this.portfolioMode,
    required this.totalValue,
  });

  factory AdminUserInfo.fromJson(Map<String, dynamic> json) {
    return AdminUserInfo(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      provider: json['provider'] ?? 'email',
      createdAt: json['created_at'] ?? '',
      lastSeenAt: json['last_seen_at'] ?? '',
      portfolioMode: json['portfolio_mode'] ?? 'demo',
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get friendlyLastSeen {
    if (lastSeenAt.isEmpty) return 'Невідомо';
    try {
      final seenTime = DateTime.parse(lastSeenAt).toUtc();
      final diff = DateTime.now().toUtc().difference(seenTime);
      if (diff.inSeconds < 60) return 'Тільки що онлайн';
      if (diff.inMinutes < 60) return '${diff.inMinutes} хв тому';
      if (diff.inHours < 24) return '${diff.inHours} год тому';
      if (diff.inDays == 1) return 'Вчора';
      if (diff.inDays < 7) return '${diff.inDays} дн. тому';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} тиж. тому';
      return '${(diff.inDays / 30).floor()} міс. тому';
    } catch (_) {
      return lastSeenAt;
    }
  }

  String get friendlyCreatedAt {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }
}

class AdminStats {
  final int totalUsers;
  final int activeToday;
  final int active7d;
  final List<AdminUserInfo> users;

  AdminStats({
    required this.totalUsers,
    required this.activeToday,
    required this.active7d,
    required this.users,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final list = (json['users'] as List?)
            ?.map((u) => AdminUserInfo.fromJson(u as Map<String, dynamic>))
            .toList() ??
        [];
    return AdminStats(
      totalUsers: json['total_users'] as int? ?? 0,
      activeToday: json['active_today'] as int? ?? 0,
      active7d: json['active_7d'] as int? ?? 0,
      users: list,
    );
  }
}

class IBKRConfig {
  final bool configured;
  final String queryId;
  final String tokenMasked;
  final String token;
  final String lastSyncAt;
  final String syncStatus;
  final String errorMessage;
  final String accountId;
  final String mode;

  IBKRConfig({
    required this.configured,
    required this.queryId,
    required this.tokenMasked,
    this.token = '',
    required this.lastSyncAt,
    required this.syncStatus,
    required this.errorMessage,
    required this.accountId,
    required this.mode,
  });

  factory IBKRConfig.fromJson(Map<String, dynamic> json) {
    return IBKRConfig(
      configured: json['configured'] as bool? ?? false,
      queryId: json['query_id'] as String? ?? '',
      tokenMasked: json['token_masked'] as String? ?? '',
      token: json['token'] as String? ?? '',
      lastSyncAt: json['last_sync_at'] as String? ?? '',
      syncStatus: json['sync_status'] as String? ?? '',
      errorMessage: json['error_message'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      mode: json['mode'] as String? ?? 'demo',
    );
  }
}

class IBKRResult {
  final bool isSuccess;
  final String status;
  final String accountId;
  final int positionsCount;
  final double cash;
  final String friendlyMessage;
  final String? warning;
  final String? errorCode;
  final String? errorMessage;
  final String? rawDetails;
  final int durationMs;
  final bool isDemo;

  IBKRResult({
    required this.isSuccess,
    required this.status,
    required this.accountId,
    required this.positionsCount,
    required this.cash,
    required this.friendlyMessage,
    this.warning,
    this.errorCode,
    this.errorMessage,
    this.rawDetails,
    this.durationMs = 0,
    this.isDemo = false,
  });

  factory IBKRResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? '';
    final isSuccess = status == 'ok' || status == 'success';
    return IBKRResult(
      isSuccess: isSuccess,
      status: status,
      accountId: json['account_id'] as String? ?? '',
      positionsCount: json['positions_count'] as int? ?? 0,
      cash: (json['cash'] as num?)?.toDouble() ?? 0.0,
      friendlyMessage: json['friendly_message'] as String? ??
          (isSuccess ? 'Підключено успішно!' : (json['error_message'] as String? ?? 'Помилка зʼєднання')),
      warning: json['warning'] as String?,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      rawDetails: json['raw_details'] as String?,
      durationMs: json['duration_ms'] as int? ?? 0,
      isDemo: json['is_demo'] as bool? ?? false,
    );
  }
}

class AdminAuditLog {
  final int id;
  final String userId;
  final String userEmail;
  final String eventType;
  final String status;
  final String accountId;
  final String queryId;
  final String tokenMasked;
  final String errorCode;
  final String message;
  final String details;
  final int durationMs;
  final String ipAddress;
  final String createdAt;

  AdminAuditLog({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.eventType,
    required this.status,
    required this.accountId,
    required this.queryId,
    required this.tokenMasked,
    required this.errorCode,
    required this.message,
    required this.details,
    required this.durationMs,
    required this.ipAddress,
    required this.createdAt,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as String? ?? '',
      userEmail: json['user_email'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      queryId: json['query_id'] as String? ?? '',
      tokenMasked: json['token_masked'] as String? ?? '',
      errorCode: json['error_code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      details: json['details'] as String? ?? '',
      durationMs: json['duration_ms'] as int? ?? 0,
      ipAddress: json['ip_address'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get friendlyCreatedAt {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return createdAt;
    }
  }
}

class MarketQuote {
  final String ticker;
  final String name;
  final double price;
  final double previousClose;
  final double change;
  final double changePercent;
  final double dayHigh;
  final double dayLow;
  final double fiftyTwoWeekHigh;
  final double fiftyTwoWeekLow;
  final String currency;
  final String exchange;

  MarketQuote({
    required this.ticker,
    required this.name,
    required this.price,
    required this.previousClose,
    required this.change,
    required this.changePercent,
    required this.dayHigh,
    required this.dayLow,
    required this.fiftyTwoWeekHigh,
    required this.fiftyTwoWeekLow,
    required this.currency,
    required this.exchange,
  });

  factory MarketQuote.fromJson(Map<String, dynamic> json) {
    return MarketQuote(
      ticker: json['ticker'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      previousClose: (json['previous_close'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0.0,
      dayHigh: (json['day_high'] as num?)?.toDouble() ?? 0.0,
      dayLow: (json['day_low'] as num?)?.toDouble() ?? 0.0,
      fiftyTwoWeekHigh: (json['fifty_two_week_high'] as num?)?.toDouble() ?? 0.0,
      fiftyTwoWeekLow: (json['fifty_two_week_low'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      exchange: json['exchange'] ?? '',
    );
  }
}

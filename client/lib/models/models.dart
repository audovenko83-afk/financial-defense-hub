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
  final double totalValue;
  final double cash;
  final double investedValue;
  final double totalDividends;
  final double totalPnL;
  final double totalPnLPercent;
  final List<Position> positions;
  final List<Dividend> dividends;

  PortfolioData({
    required this.totalValue,
    required this.cash,
    required this.investedValue,
    required this.totalDividends,
    required this.totalPnL,
    required this.totalPnLPercent,
    required this.positions,
    required this.dividends,
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
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
      cash: (json['cash'] as num?)?.toDouble() ?? 0.0,
      investedValue: (json['invested_value'] as num?)?.toDouble() ?? 0.0,
      totalDividends: (json['total_dividends'] as num?)?.toDouble() ?? 0.0,
      totalPnL: (json['total_pnl'] as num?)?.toDouble() ?? 0.0,
      totalPnLPercent: (json['total_pnl_percent'] as num?)?.toDouble() ?? 0.0,
      positions: posList,
      dividends: divList,
    );
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

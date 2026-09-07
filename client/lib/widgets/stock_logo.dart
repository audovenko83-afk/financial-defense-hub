import 'package:flutter/material.dart';

class StockLogo extends StatelessWidget {
  final String ticker;
  final double size;
  final double borderRadius;

  const StockLogo({
    super.key,
    required this.ticker,
    this.size = 40.0,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final cleanTicker = ticker.trim().toUpperCase();
    final logoUrl = 'https://assets.parqet.com/logos/symbol/$cleanTicker?format=png';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        logoUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildFallback(cleanTicker);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback(cleanTicker);
        },
      ),
    );
  }

  Widget _buildFallback(String symbol) {
    final colors = _getBrandColors(symbol);
    final displaySymbol = symbol.length > 4 ? symbol.substring(0, 4) : symbol;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          displaySymbol,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.32,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  List<Color> _getBrandColors(String symbol) {
    switch (symbol) {
      case 'AAPL':
        return [const Color(0xFF555555), const Color(0xFF1E1E1E)];
      case 'MSFT':
        return [const Color(0xFF0078D4), const Color(0xFF104A7B)];
      case 'NVDA':
        return [const Color(0xFF76B900), const Color(0xFF1E3A00)];
      case 'GOOGL':
      case 'GOOG':
        return [const Color(0xFF4285F4), const Color(0xFF0F9D58)];
      case 'AMZN':
        return [const Color(0xFFFF9900), const Color(0xFF232F3E)];
      case 'META':
        return [const Color(0xFF0081FB), const Color(0xFF064789)];
      case 'TSLA':
        return [const Color(0xFFE82127), const Color(0xFF8B0000)];
      case 'VOO':
      case 'SPY':
        return [const Color(0xFF00FF94), const Color(0xFF007A48)];
      case 'QQQ':
        return [const Color(0xFF00E5FF), const Color(0xFF005B66)];
      case 'ADBE':
        return [const Color(0xFFFA0F00), const Color(0xFF800000)];
      case 'BRK.B':
        return [const Color(0xFF2D3748), const Color(0xFF1A202C)];
      default:
        // Deterministic gradient by ticker letters
        final hash = symbol.hashCode.abs();
        final hue1 = (hash % 360).toDouble();
        final hue2 = ((hash + 45) % 360).toDouble();
        return [
          HSVColor.fromAHSV(1.0, hue1, 0.7, 0.45).toColor(),
          HSVColor.fromAHSV(1.0, hue2, 0.8, 0.25).toColor(),
        ];
    }
  }
}

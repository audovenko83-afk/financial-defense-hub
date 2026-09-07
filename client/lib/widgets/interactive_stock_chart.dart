import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChartPoint {
  final String date;
  final double close;

  const ChartPoint({required this.date, required this.close});
}

class InteractiveStockChart extends StatefulWidget {
  final List<ChartPoint> points;
  final String selectedRange;
  final Function(String range) onRangeChanged;
  final bool isLoading;
  final double? currentPrice;

  const InteractiveStockChart({
    super.key,
    required this.points,
    required this.selectedRange,
    required this.onRangeChanged,
    this.isLoading = false,
    this.currentPrice,
  });

  @override
  State<InteractiveStockChart> createState() => _InteractiveStockChartState();
}

class _InteractiveStockChartState extends State<InteractiveStockChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final hasPoints = points.isNotEmpty;

    double minPrice = 0.0;
    double maxPrice = 0.0;
    double firstPrice = 0.0;
    double lastPrice = widget.currentPrice ?? 0.0;

    if (hasPoints) {
      minPrice = points.map((p) => p.close).reduce(math.min);
      maxPrice = points.map((p) => p.close).reduce(math.max);
      firstPrice = points.first.close;
      lastPrice = points.last.close;
    }

    final activePoint = (_hoverIndex != null && _hoverIndex! < points.length)
        ? points[_hoverIndex!]
        : (hasPoints ? points.last : null);

    final displayPrice = activePoint?.close ?? lastPrice;
    final displayDate = activePoint?.date ?? '';
    final diffFromStart = hasPoints ? displayPrice - firstPrice : 0.0;
    final diffPercent = (hasPoints && firstPrice > 0) ? (diffFromStart / firstPrice) * 100 : 0.0;
    final isPositive = diffFromStart >= 0;
    final accentColor = isPositive ? const Color(0xFF00FF94) : const Color(0xFFFF5252);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161B26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hoverIndex != null ? 'ДАТА: $displayDate' : 'ОГЛЯД ПЕРІОДУ',
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  Text('\$${displayPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_hoverIndex != null ? 'Зміна' : 'Динаміка за період', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(isPositive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: accentColor, size: 20),
                      Text(
                        '${isPositive ? '+' : ''}\$${diffFromStart.toStringAsFixed(2)} (${isPositive ? '+' : ''}${diffPercent.toStringAsFixed(2)}%)',
                        style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildCanvas(points, hasPoints, minPrice, maxPrice, firstPrice, isPositive),
        const SizedBox(height: 10),
        _buildRangeButtons(),
      ],
    );
  }

  Widget _buildCanvas(List<ChartPoint> points, bool hasPoints, double minPrice, double maxPrice, double firstPrice, bool isPositive) {
    return Container(
      height: 145,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: widget.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF94), strokeWidth: 2))
          : !hasPoints
              ? const Center(child: Text('Котирування завантажуються...', style: TextStyle(color: Colors.white38, fontSize: 12)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onHorizontalDragStart: (d) => _updateHover(d.localPosition.dx, constraints.maxWidth, points.length),
                      onHorizontalDragUpdate: (d) => _updateHover(d.localPosition.dx, constraints.maxWidth, points.length),
                      onHorizontalDragEnd: (_) => setState(() => _hoverIndex = null),
                      onTapDown: (d) => _updateHover(d.localPosition.dx, constraints.maxWidth, points.length),
                      onTapUp: (_) => setState(() => _hoverIndex = null),
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: _StockChartPainter(
                              points: points,
                              hoverIndex: _hoverIndex,
                              isPositive: isPositive,
                              minPrice: minPrice,
                              maxPrice: maxPrice,
                              firstPrice: firstPrice,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            left: 10,
                            child: Text('Макс: \$${maxPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Positioned(
                            bottom: 6,
                            left: 10,
                            child: Text('Мін: \$${minPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildRangeButtons() {
    final ranges = [
      {'key': '5d', 'label': '5Д'},
      {'key': '1mo', 'label': '1М'},
      {'key': '6mo', 'label': '6М'},
      {'key': '1y', 'label': '1Р'},
      {'key': '5y', 'label': '5Р'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ranges.map((item) {
        final rangeKey = item['key']!;
        final label = item['label']!;
        final isSel = widget.selectedRange == rangeKey;

        return InkWell(
          onTap: () => widget.onRangeChanged(rangeKey),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF00FF94).withValues(alpha: 0.18) : const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSel ? const Color(0xFF00FF94) : Colors.white.withValues(alpha: 0.06)),
            ),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isSel ? const Color(0xFF00FF94) : Colors.white60)),
          ),
        );
      }).toList(),
    );
  }

  void _updateHover(double dx, double width, int count) {
    if (count <= 1 || width <= 0) return;
    final clampedX = dx.clamp(0.0, width);
    final ratio = clampedX / width;
    final index = (ratio * (count - 1)).round().clamp(0, count - 1);
    setState(() => _hoverIndex = index);
  }
}

class _StockChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final int? hoverIndex;
  final bool isPositive;
  final double minPrice;
  final double maxPrice;
  final double firstPrice;

  _StockChartPainter({
    required this.points,
    required this.hoverIndex,
    required this.isPositive,
    required this.minPrice,
    required this.maxPrice,
    required this.firstPrice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final primaryColor = isPositive ? const Color(0xFF00FF94) : const Color(0xFFFF5252);
    final range = maxPrice - minPrice <= 0 ? 1.0 : maxPrice - minPrice;
    const paddingTop = 16.0;
    const paddingBottom = 16.0;
    final chartHeight = size.height - paddingTop - paddingBottom;

    double getY(double price) {
      final norm = (price - minPrice) / range;
      return size.height - paddingBottom - (norm * chartHeight);
    }

    double getX(int i) {
      return (i / (points.length - 1)) * size.width;
    }

    // Baseline reference (dashed)
    final baselineY = getY(firstPrice);
    final dashedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double dashX = 0;
    while (dashX < size.width) {
      canvas.drawLine(Offset(dashX, baselineY), Offset(math.min(dashX + 5, size.width), baselineY), dashedPaint);
      dashX += 9;
    }

    // Construct curve path
    final linePath = Path();
    final fillPath = Path();

    linePath.moveTo(getX(0), getY(points[0].close));
    fillPath.moveTo(getX(0), size.height);
    fillPath.lineTo(getX(0), getY(points[0].close));

    for (int i = 0; i < points.length - 1; i++) {
      final x1 = getX(i);
      final y1 = getY(points[i].close);
      final x2 = getX(i + 1);
      final y2 = getY(points[i + 1].close);

      final controlX = (x1 + x2) / 2;
      linePath.cubicTo(controlX, y1, controlX, y2, x2, y2);
      fillPath.cubicTo(controlX, y1, controlX, y2, x2, y2);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Gradient fill under curve
    final fillGradient = LinearGradient(
      colors: [
        primaryColor.withValues(alpha: 0.28),
        primaryColor.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Hover indicator cursor and vertical guide line
    if (hoverIndex != null && hoverIndex! < points.length) {
      final hX = getX(hoverIndex!);
      final hY = getY(points[hoverIndex!].close);

      final hoverLinePaint = Paint()
        ..color = Colors.white38
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(hX, paddingTop), Offset(hX, size.height - paddingBottom), hoverLinePaint);

      final haloPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(hX, hY), 8.0, haloPaint);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(hX, hY), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StockChartPainter old) {
    return old.points != points || old.hoverIndex != hoverIndex || old.isPositive != isPositive;
  }
}


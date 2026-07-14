import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

// ── Donut Chart ───────────────────────────────────────────
class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final int total;
  const DonutChart({super.key, required this.segments, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160, height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(160, 160), painter: _DonutPainter(segments)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(total.toString(), style: GoogleFonts.dmSans(
                fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text1,
              )),
              Text('TOTAL', style: GoogleFonts.dmSans(
                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 2,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutSegment {
  final double pct;
  final Color color;
  final String label;
  const DonutSegment({required this.pct, required this.color, required this.label});
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width / 2 - 14;
    const strokeW = 14.0;
    double startAngle = -pi / 2;
    for (final seg in segments) {
      final sweep = 2 * pi * seg.pct / 100;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweep, false, paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Line / Area Chart ─────────────────────────────────────
class LineAreaChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  const LineAreaChart({super.key, required this.values, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineAreaPainter(values, color),
      child: const SizedBox.expand(),
    );
  }
}

class _LineAreaPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _LineAreaPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = 6.0, maxV = 25.0;
    final W = size.width, H = size.height;

    double px(int i) => (i / (values.length - 1)) * (W - 20) + 10;
    double py(double v) => H - ((v - minV) / (maxV - minV)) * H * 0.85 - 10;

    final pts = [for (var i = 0; i < values.length; i++) Offset(px(i), py(values[i]))];

    final linePath = Path();
    linePath.moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) linePath.lineTo(pts[i].dx, pts[i].dy);

    // Area
    final areaPath = Path.from(linePath)
      ..lineTo(pts.last.dx, H)
      ..lineTo(pts.first.dx, H)
      ..close();
    final grad = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.15), color.withOpacity(0.01)],
    );
    canvas.drawPath(areaPath, Paint()..shader = grad.createShader(Rect.fromLTWH(0, 0, W, H)));

    // Line
    canvas.drawPath(linePath, Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);

    // Dots
    for (final p in pts) {
      canvas.drawCircle(p, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Bar + Line combo ──────────────────────────────────────
class BarLineChart extends StatelessWidget {
  final List<double> barValues;
  final List<double> lineValues;
  final List<String> labels;
  const BarLineChart({super.key, required this.barValues, required this.lineValues, required this.labels});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarLinePainter(barValues, lineValues, labels),
      child: const SizedBox.expand(),
    );
  }
}

class _BarLinePainter extends CustomPainter {
  final List<double> bars, line;
  final List<String> labels;
  _BarLinePainter(this.bars, this.line, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height - 20, pad = 10.0;
    final maxV = bars.reduce(max) * 1.1;
    final n = bars.length;
    final bw = (W - pad * 2) / n;
    final barW = bw * 0.35;

    double bx(int i) => pad + i * bw + bw / 2;
    double py(double v) => H - (v / maxV) * (H - 16) - 4;

    // Grid lines
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      final y = H - f * (H - 16) - 4;
      canvas.drawLine(Offset(pad, y), Offset(W - pad, y),
          Paint()..color = const Color(0xFFF3F4F6)..strokeWidth = 1);
    }

    // Bars
    for (var i = 0; i < bars.length; i++) {
      final rect = Rect.fromLTWH(bx(i) - barW / 2, py(bars[i]), barW, H - py(bars[i]) - 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF374151).withOpacity(0.75),
      );
    }

    // Net line
    final linePts = [for (var i = 0; i < line.length; i++) Offset(bx(i), py(line[i]))];
    final linePath = Path();
    linePath.moveTo(linePts[0].dx, linePts[0].dy);
    for (var i = 1; i < linePts.length; i++) linePath.lineTo(linePts[i].dx, linePts[i].dy);
    canvas.drawPath(linePath, Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);

    for (final p in linePts) {
      canvas.drawCircle(p, 3, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3, Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

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

// ── Line / Area Chart (interactif : survol + infobulle) ───
class LineAreaChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final String Function(double)? tooltipFormatter;
  const LineAreaChart({
    super.key, required this.values, this.labels = const [],
    this.color = AppColors.primary, this.tooltipFormatter,
  });

  @override
  State<LineAreaChart> createState() => _LineAreaChartState();
}

class _LineAreaChartState extends State<LineAreaChart> {
  int? _hoverIndex;

  int _nearestIndex(double dx, double width) {
    final n = widget.values.length;
    if (n <= 1) return 0;
    final t = ((dx - 10) / (width - 20)).clamp(0.0, 1.0);
    return (t * (n - 1)).round().clamp(0, n - 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return MouseRegion(
        onHover: (e) => setState(() => _hoverIndex = _nearestIndex(e.localPosition.dx, constraints.maxWidth)),
        onExit: (_) => setState(() => _hoverIndex = null),
        child: GestureDetector(
          onTapDown: (d) => setState(() => _hoverIndex = _nearestIndex(d.localPosition.dx, constraints.maxWidth)),
          child: CustomPaint(
            painter: _LineAreaPainter(
              widget.values, widget.color,
              hoverIndex: _hoverIndex,
              labels: widget.labels,
              tooltipFormatter: widget.tooltipFormatter,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    });
  }
}

class _LineAreaPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int? hoverIndex;
  final List<String> labels;
  final String Function(double)? tooltipFormatter;
  _LineAreaPainter(this.values, this.color, {this.hoverIndex, this.labels = const [], this.tooltipFormatter});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    // Échelle calculée à partir des données (avec marge)
    final lo = values.reduce(min), hi = values.reduce(max);
    final span = (hi - lo).abs() < 0.001 ? 1.0 : hi - lo;
    final minV = lo - span * 0.15, maxV = hi + span * 0.15;
    final W = size.width, H = size.height;

    double px(int i) => values.length == 1 ? W / 2 : (i / (values.length - 1)) * (W - 20) + 10;
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

    // ── Survol : ligne guide + point agrandi + infobulle ──
    final hi2 = hoverIndex;
    if (hi2 != null && hi2 >= 0 && hi2 < pts.length) {
      final p = pts[hi2];

      // Ligne guide verticale
      canvas.drawLine(
        Offset(p.dx, 0), Offset(p.dx, H),
        Paint()..color = color.withOpacity(0.25)..strokeWidth = 1,
      );

      // Point agrandi (halo blanc + couleur)
      canvas.drawCircle(p, 7, Paint()..color = Colors.white);
      canvas.drawCircle(p, 5.5, Paint()..color = color);

      // Infobulle
      final label = hi2 < labels.length ? labels[hi2] : '';
      final valueTxt = tooltipFormatter?.call(values[hi2]) ?? values[hi2].toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(children: [
          if (label.isNotEmpty)
            TextSpan(text: '$label\n', style: GoogleFonts.dmSans(
              fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.75))),
          TextSpan(text: valueTxt, style: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      const padH = 10.0, padV = 6.0;
      final boxW = tp.width + padH * 2, boxH = tp.height + padV * 2;
      var boxX = p.dx - boxW / 2;
      var boxY = p.dy - boxH - 14;
      boxX = boxX.clamp(2.0, W - boxW - 2);
      if (boxY < 2) boxY = p.dy + 14;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(7));
      canvas.drawRRect(rrect, Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF1F2433));
      tp.paint(canvas, Offset(boxX + padH, boxY + padV));
    }
  }

  @override
  bool shouldRepaint(covariant _LineAreaPainter old) =>
      old.hoverIndex != hoverIndex || old.values != values || old.color != color;
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

import 'dart:math';
import 'package:flutter/material.dart';

/// 进京证朱砂印章风格地图标记
class JinjingMarker extends StatelessWidget {
  final double size;

  const JinjingMarker({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _JinjingMarkerPainter()),
    );
  }
}

class _JinjingMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;

    // ── 主体轮廓（朱砂红，带毛笔晕染模糊）─────────────────────────
    final bodyPath = Path()
      ..moveTo(50 * s, 87 * s)
      ..lineTo(25 * s, 56 * s)
      ..quadraticBezierTo(19 * s, 50 * s, 19 * s, 40 * s)
      ..arcToPoint(
        Offset(81 * s, 40 * s),
        radius: Radius.circular(31 * s),
        clockwise: true,
        largeArc: true,
      )
      ..quadraticBezierTo(81 * s, 50 * s, 75 * s, 56 * s)
      ..close();

    // 晕染底层（稍大、深红，模拟印章墨迹扩散）
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0x558B0000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 主体填充
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0xF0B22222)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    // ── 内框（白色虚线描边，印章边框感）─────────────────────────────
    final innerPath = Path()
      ..moveTo(50 * s, 80 * s)
      ..lineTo(31 * s, 55 * s)
      ..quadraticBezierTo(25 * s, 50 * s, 25 * s, 40 * s)
      ..arcToPoint(
        Offset(75 * s, 40 * s),
        radius: Radius.circular(25 * s),
        clockwise: true,
        largeArc: true,
      )
      ..quadraticBezierTo(75 * s, 50 * s, 69 * s, 55 * s)
      ..close();

    _drawDashedPath(
      canvas,
      innerPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * s,
      dashLength: 4.5 * s,
      gapLength: 2.5 * s,
    );

    // ── 城门图标（正阳门象征）────────────────────────────────────────
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 城墙主体（门洞左柱 + 横梁 + 右柱）
    canvas.drawPath(
      Path()
        ..moveTo(38 * s, 52 * s)
        ..lineTo(38 * s, 34 * s)
        ..lineTo(62 * s, 34 * s)
        ..lineTo(62 * s, 52 * s),
      iconPaint,
    );

    // 横向腰线
    canvas.drawLine(
      Offset(34 * s, 42 * s),
      Offset(66 * s, 42 * s),
      iconPaint,
    );

    // 门洞（半圆拱）
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(50 * s, 52 * s),
        width: 16 * s,
        height: 14 * s,
      ),
      pi,
      pi,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 在 Canvas 上绘制虚线 Path
  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        final len = draw ? dashLength : gapLength;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(dist, dist + len),
            paint,
          );
        }
        dist += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

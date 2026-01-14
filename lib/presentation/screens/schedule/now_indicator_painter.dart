import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'shared/utils/time_utils.dart';

class NowIndicatorPaintLayer extends StatelessWidget {
  final ValueListenable<DateTime> nowListenable;
  final bool showLine;
  final bool showThickTodayLine;
  final double gutterWidth;
  final double? todayLeft;
  final double? todayWidth;

  const NowIndicatorPaintLayer({
    super.key,
    required this.nowListenable,
    required this.showLine,
    required this.showThickTodayLine,
    required this.gutterWidth,
    this.todayLeft,
    this.todayWidth,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: NowIndicatorPainter(
            nowListenable: nowListenable,
            showLine: showLine,
            showThickTodayLine: showThickTodayLine,
            gutterWidth: gutterWidth,
            todayLeft: todayLeft,
            todayWidth: todayWidth,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class NowIndicatorPainter extends CustomPainter {
  final ValueListenable<DateTime> nowListenable;
  final bool showLine;
  final bool showThickTodayLine;
  final double gutterWidth;
  final double? todayLeft;
  final double? todayWidth;

  NowIndicatorPainter({
    required this.nowListenable,
    required this.showLine,
    required this.showThickTodayLine,
    required this.gutterWidth,
    this.todayLeft,
    this.todayWidth,
  }) : super(repaint: nowListenable);

  @override
  void paint(Canvas canvas, Size size) {
    // Step 3: skeleton only.
    // Step 4 will implement actual drawing of time label and red line(s).

    final now = nowListenable.value;
    final y = TimeUtils.timeToY(now);

    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final timeText = '$hh:$mm';

    const padH = 6.0;
    const padV = 2.0;
    final textPainter = TextPainter(
      text: const TextSpan(
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        children: <InlineSpan>[],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.text = TextSpan(
      text: timeText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    textPainter.layout(maxWidth: gutterWidth);

    final labelW = textPainter.width + padH * 2;
    final labelH = textPainter.height + padV * 2;
    final labelLeft = (gutterWidth - labelW).clamp(0.0, gutterWidth);
    final labelTop = y - labelH / 2;

    final bgRect = Rect.fromLTWH(labelLeft, labelTop, labelW, labelH);
    final bgRRect = RRect.fromRectAndRadius(bgRect, const Radius.circular(4));
    final bgPaint = Paint()..color = Colors.red;
    canvas.drawRRect(bgRRect, bgPaint);
    textPainter.paint(canvas, Offset(labelLeft + padH, labelTop + padV));

    if (showLine) {
      const thinHeight = 1.5;
      final thinPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = thinHeight
        ..strokeCap = StrokeCap.butt;

      canvas.drawLine(Offset(gutterWidth, y), Offset(size.width, y), thinPaint);
    }

    if (showThickTodayLine && todayLeft != null && todayWidth != null) {
      const thickHeight = 3.0;
      final thickPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = thickHeight
        ..strokeCap = StrokeCap.butt;

      canvas.drawLine(
        Offset(todayLeft!, y),
        Offset(todayLeft! + todayWidth!, y),
        thickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant NowIndicatorPainter oldDelegate) {
    return oldDelegate.showLine != showLine ||
        oldDelegate.showThickTodayLine != showThickTodayLine ||
        oldDelegate.gutterWidth != gutterWidth ||
        oldDelegate.todayLeft != todayLeft ||
        oldDelegate.todayWidth != todayWidth;
  }
}

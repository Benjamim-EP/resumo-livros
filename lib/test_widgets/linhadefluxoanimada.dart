import 'package:flutter/material.dart';
import 'dart:ui';

class AnimatedFlowLine extends StatefulWidget {
  final Offset start;
  final Offset end;
  final Color lineColor;
  final double thickness;
  final Color flowColor;
  final double flowSize;
  final Duration duration;

  const AnimatedFlowLine({
    super.key,
    required this.start,
    required this.end,
    this.lineColor = Colors.white,
    this.thickness = 4.0,
    this.flowColor = Colors.greenAccent,
    this.flowSize = 8.0,
    this.duration = const Duration(seconds: 2),
  });

  @override
  _AnimatedFlowLineState createState() => _AnimatedFlowLineState();
}

class _AnimatedFlowLineState extends State<AnimatedFlowLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: false);

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FlowLinePainter(
        start: widget.start,
        end: widget.end,
        lineColor: widget.lineColor,
        thickness: widget.thickness,
        flowColor: widget.flowColor,
        flowSize: widget.flowSize,
        animation: _animation,
      ),
    );
  }
}

class FlowLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color lineColor;
  final double thickness;
  final Color flowColor;
  final double flowSize;
  final Animation<double> animation;

  FlowLinePainter({
    required this.start,
    required this.end,
    required this.lineColor,
    required this.thickness,
    required this.flowColor,
    required this.flowSize,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = lineColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2 - 50, // Curva suave para cima
        end.dx,
        end.dy,
      );

    // Aplicando efeito neon com máscara de desfoque
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paintLine);

    // Calcula a posição do fluxo de energia na linha animada
    final pathMetrics = path.computeMetrics();
    for (var metric in pathMetrics) {
      final pos = metric.getTangentForOffset(metric.length * animation.value);
      if (pos != null) {
        final glowCirclePaint = Paint()
          ..color = flowColor.withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

        final circlePaint = Paint()..color = flowColor;

        // Aplicando efeito neon na bolinha do fluxo
        canvas.drawCircle(pos.position, flowSize, glowCirclePaint);
        canvas.drawCircle(pos.position, flowSize / 2, circlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

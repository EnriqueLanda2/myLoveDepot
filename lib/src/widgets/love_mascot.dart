import 'package:flutter/material.dart';

/// Personaje amarillo original de la marca. Se dibuja con Flutter para que se
/// vea nítido en cualquier pantalla y no dependa de una conexión a internet.
class LoveMascot extends StatelessWidget {
  const LoveMascot({this.size = 52, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Mascota amarilla sosteniendo un corazón rosa',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _LoveMascotPainter()),
        ),
      );
}

class _LoveMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.scale(scale, scale);
    final body = Paint()..color = const Color(0xffffd54f);
    final outline = Paint()
      ..color = const Color(0xff4f4450)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final blue = Paint()..color = const Color(0xff5677a6);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(21, 7, 58, 82), const Radius.circular(27)),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(27, 58, 46, 31), const Radius.circular(11)),
      blue,
    );
    canvas.drawLine(const Offset(30, 57), const Offset(24, 43), outline);
    canvas.drawLine(const Offset(70, 57), const Offset(76, 43), outline);

    canvas.drawCircle(
        const Offset(50, 35), 17, Paint()..color = const Color(0xffddd7dc));
    canvas.drawCircle(const Offset(50, 35), 12, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(50, 35), 6, Paint()..color = const Color(0xff6d4c41));
    canvas.drawCircle(const Offset(52, 33), 2, Paint()..color = Colors.white);
    canvas.drawLine(const Offset(21, 31), const Offset(34, 31), outline);
    canvas.drawLine(const Offset(66, 31), const Offset(79, 31), outline);
    canvas.drawArc(
        const Rect.fromLTWH(39, 42, 22, 16), .15, 2.8, false, outline);

    final heart = Path()
      ..moveTo(75, 60)
      ..cubicTo(65, 50, 55, 65, 75, 82)
      ..cubicTo(95, 65, 85, 50, 75, 60)
      ..close();
    canvas.drawPath(heart, Paint()..color = const Color(0xfff06292));
    canvas.drawLine(const Offset(65, 69), const Offset(52, 65), outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

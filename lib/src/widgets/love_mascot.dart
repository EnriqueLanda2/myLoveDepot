import 'package:flutter/material.dart';

/// Personaje amarillo de la marca con DOS OJOS normales (estilo Minion clásico).
/// Se dibuja con Flutter para que se vea nítido en cualquier pantalla y no
/// dependa de una conexión a internet.
class LoveMascot extends StatelessWidget {
  const LoveMascot({this.size = 52, this.animate = false, super.key});

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    Widget child = Semantics(
      label: 'Mascota amarilla con dos ojos sosteniendo un corazón rosa',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LoveMascotPainter()),
      ),
    );

    if (animate) {
      child = _BouncingWrapper(child: child);
    }

    return child;
  }
}

/// Wrapper that gives the mascot a gentle idle bounce animation.
class _BouncingWrapper extends StatefulWidget {
  const _BouncingWrapper({required this.child});
  final Widget child;

  @override
  State<_BouncingWrapper> createState() => _BouncingWrapperState();
}

class _BouncingWrapperState extends State<_BouncingWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _bounce.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _LoveMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.scale(scale, scale);

    // ── Colores ──────────────────────────────────────────────────────────────
    final body = Paint()..color = const Color(0xffffd54f);
    final bodyDark = Paint()..color = const Color(0xfff0c030); // sombra cuerpo
    final outline = Paint()
      ..color = const Color(0xff3d3040)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outlineThin = Paint()
      ..color = const Color(0xff3d3040)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final blue = Paint()..color = const Color(0xff4a6fa5);
    final blueDark = Paint()..color = const Color(0xff3b5a87);
    final goggleRim = Paint()
      ..color = const Color(0xff8a8a8a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final goggleRimFill = Paint()..color = const Color(0xffb0b0b0);
    final white = Paint()..color = Colors.white;
    final iris = Paint()..color = const Color(0xff6d4230);
    final pupil = Paint()..color = const Color(0xff1a1018);
    final highlight = Paint()..color = const Color(0xffffffff);
    final mouthFill = Paint()..color = const Color(0xff3d3040);

    // ── Cuerpo (pill / cápsula redondeada) ───────────────────────────────────
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 8, 56, 80),
      const Radius.circular(26),
    );
    // Sombra sutil
    canvas.drawRRect(
      bodyRect.shift(const Offset(1.5, 2)),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(bodyRect, body);

    // Sombreado lateral izquierdo del cuerpo (volumen)
    canvas.save();
    canvas.clipRRect(bodyRect);
    canvas.drawOval(
      const Rect.fromLTWH(55, 10, 30, 76),
      Paint()
        ..color = const Color(0x15000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.restore();

    // ── Overol azul (pantalón inferior) ──────────────────────────────────────
    final overallPath = Path()
      ..moveTo(22, 55)
      ..lineTo(78, 55)
      ..lineTo(78, 62)
      ..quadraticBezierTo(78, 88, 52, 88)
      ..quadraticBezierTo(22, 88, 22, 62)
      ..close();
    canvas.save();
    canvas.clipRRect(bodyRect);
    canvas.drawPath(overallPath, blue);

    // Bolsillo central
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(39, 56, 22, 14),
        const Radius.circular(4),
      ),
      blueDark,
    );
    // Borde del bolsillo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(39, 56, 22, 14),
        const Radius.circular(4),
      ),
      Paint()
        ..color = const Color(0xff2e4a6e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();

    // Tirantes del overol
    canvas.drawLine(
      const Offset(34, 52),
      const Offset(30, 42),
      outlineThin,
    );
    canvas.drawLine(
      const Offset(66, 52),
      const Offset(70, 42),
      outlineThin,
    );
    // Botones de tirantes
    canvas.drawCircle(const Offset(30, 42), 2.5, Paint()..color = const Color(0xff555555));
    canvas.drawCircle(const Offset(70, 42), 2.5, Paint()..color = const Color(0xff555555));

    // ── Brazos ───────────────────────────────────────────────────────────────
    // Brazo izquierdo (levantado sosteniendo corazón)
    final leftArm = Path()
      ..moveTo(22, 48)
      ..quadraticBezierTo(10, 44, 12, 56);
    canvas.drawPath(leftArm, body);
    canvas.drawPath(leftArm, outlineThin);
    // Mano izquierda
    canvas.drawCircle(const Offset(12, 57), 4, body);
    canvas.drawCircle(const Offset(12, 57), 4, outlineThin);

    // Brazo derecho (sosteniendo corazón)
    final rightArm = Path()
      ..moveTo(78, 48)
      ..quadraticBezierTo(90, 44, 88, 56);
    canvas.drawPath(rightArm, body);
    canvas.drawPath(rightArm, outlineThin);
    // Mano derecha
    canvas.drawCircle(const Offset(88, 57), 4, body);
    canvas.drawCircle(const Offset(88, 57), 4, outlineThin);

    // ── Piernas (asomando bajo el overol) ────────────────────────────────────
    // Pierna izquierda
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(33, 84, 12, 10),
        const Radius.circular(5),
      ),
      body,
    );
    // Zapato izquierdo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 90, 17, 7),
        const Radius.circular(3.5),
      ),
      Paint()..color = const Color(0xff2d2d2d),
    );

    // Pierna derecha
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(55, 84, 12, 10),
        const Radius.circular(5),
      ),
      body,
    );
    // Zapato derecho
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(53, 90, 17, 7),
        const Radius.circular(3.5),
      ),
      Paint()..color = const Color(0xff2d2d2d),
    );

    // ── Gafas / Goggles (DOS OJOS) ──────────────────────────────────────────
    // Banda de las gafas (correa detrás de la cabeza)
    canvas.drawLine(
      const Offset(20, 28),
      const Offset(80, 28),
      Paint()
        ..color = const Color(0xff6a6a6a)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Aro izquierdo (goggle)
    canvas.drawCircle(const Offset(39, 28), 13, goggleRimFill);
    canvas.drawCircle(const Offset(39, 28), 13, goggleRim);

    // Aro derecho (goggle)
    canvas.drawCircle(const Offset(61, 28), 13, goggleRimFill);
    canvas.drawCircle(const Offset(61, 28), 13, goggleRim);

    // Puente entre goggles
    canvas.drawLine(
      const Offset(52, 28),
      const Offset(48, 28),
      Paint()
        ..color = const Color(0xff8a8a8a)
        ..strokeWidth = 3,
    );

    // ── Ojo Izquierdo ────────────────────────────────────────────────────────
    canvas.drawCircle(const Offset(39, 28), 10, white); // esclerótica
    canvas.drawCircle(const Offset(40, 28), 5.5, iris);  // iris
    canvas.drawCircle(const Offset(40.5, 27.5), 3, pupil); // pupila
    canvas.drawCircle(const Offset(42, 26), 1.8, highlight); // brillo
    canvas.drawCircle(const Offset(38, 30), 0.8, highlight); // brillo secundario

    // ── Ojo Derecho ──────────────────────────────────────────────────────────
    canvas.drawCircle(const Offset(61, 28), 10, white); // esclerótica
    canvas.drawCircle(const Offset(62, 28), 5.5, iris);  // iris
    canvas.drawCircle(const Offset(62.5, 27.5), 3, pupil); // pupila
    canvas.drawCircle(const Offset(64, 26), 1.8, highlight); // brillo
    canvas.drawCircle(const Offset(60, 30), 0.8, highlight); // brillo secundario

    // ── Boca (sonrisa amigable) ─────────────────────────────────────────────
    final smile = Path()
      ..moveTo(40, 39)
      ..quadraticBezierTo(50, 47, 60, 39);
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xff3d3040)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // ── Pelo / mechones (3 pelitos en la cabeza) ────────────────────────────
    final hair = Paint()
      ..color = const Color(0xff3d3040)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Mechón central
    final h1 = Path()
      ..moveTo(50, 10)
      ..quadraticBezierTo(49, 2, 52, 0);
    canvas.drawPath(h1, hair);

    // Mechón izquierdo
    final h2 = Path()
      ..moveTo(44, 11)
      ..quadraticBezierTo(40, 4, 38, 2);
    canvas.drawPath(h2, hair);

    // Mechón derecho
    final h3 = Path()
      ..moveTo(56, 11)
      ..quadraticBezierTo(60, 4, 62, 2);
    canvas.drawPath(h3, hair);

    // ── Corazón rosa (sostenido con las manos) ──────────────────────────────
    canvas.save();
    canvas.translate(75, 52);
    canvas.scale(0.75, 0.75);
    final heart = Path()
      ..moveTo(0, 8)
      ..cubicTo(-10, -2, -20, 12, 0, 28)
      ..cubicTo(20, 12, 10, -2, 0, 8)
      ..close();
    // Sombra del corazón
    canvas.drawPath(
      heart.shift(const Offset(1.5, 2)),
      Paint()
        ..color = const Color(0x30000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(heart, Paint()..color = const Color(0xfff06292));
    // Brillo del corazón
    canvas.drawCircle(
      const Offset(-4, 12),
      3,
      Paint()
        ..color = const Color(0x40ffffff)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

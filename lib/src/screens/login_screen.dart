import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../widgets/love_mascot.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.store, super.key});
  final InventoryStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;
  late final AnimationController _pulse;
  late final Animation<double> _glow;
  late final AnimationController _float;
  late final Animation<double> _floatAnim;

  // Paleta refinada
  static const _magenta = Color(0xffd94f87);
  static const _magentaDeep = Color(0xffb5296b);
  static const _bgGrad1 = Color(0xffffedf5);
  static const _bgGrad2 = Color(0xfffff8d9);
  static const _bgGrad3 = Color(0xfffffbfd);
  static const _textPrimary = Color(0xff3a2633);
  static const _textSecondary = Color(0xff7a5c6b);
  static const _stroke = Color(0xffe8d0da);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.08, end: 0.25).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _float, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    _pulse.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgGrad1, _bgGrad2, _bgGrad3],
          ),
        ),
        child: Stack(
          children: [
            // Animated glow
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glow,
                builder: (context, _) => CustomPaint(
                  painter: _SoftGlowPainter(
                    color: _magenta,
                    opacity: _glow.value,
                  ),
                ),
              ),
            ),

            // Floating decorative shapes
            ..._buildDecoShapes(),

            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      // ── Mascot (floating) ────────────────────────────────
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: child,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.9),
                                const Color(0xffffedf5).withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _magenta.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _magenta.withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const LoveMascot(size: 100),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Card de Login ────────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: _stroke.withValues(alpha: 0.6),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _magenta.withValues(alpha: 0.06),
                              blurRadius: 40,
                              spreadRadius: 0,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 36,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [_magenta, _magentaDeep],
                              ).createShader(bounds),
                              child: const Text(
                                'My Love Depot',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nuestro pequeño espacio, hecho con\namor para ti 💛',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Divider decorativo
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          _stroke.withValues(alpha: 0.7),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Icon(
                                    Icons.favorite,
                                    size: 14,
                                    color: _magenta.withValues(alpha: 0.4),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _stroke.withValues(alpha: 0.7),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // ── Campo usuario ──────────────────────────────
                            _PremiumField(
                              controller: username,
                              label: 'Tu usuario',
                              hint: 'Escribe tu usuario',
                              icon: Icons.person_rounded,
                              autofillHints: const [AutofillHints.username],
                            ),
                            const SizedBox(height: 16),

                            // ── Campo contraseña ───────────────────────────
                            _PremiumField(
                              controller: password,
                              label: 'Tu contraseña',
                              hint: 'Mínimo 8 caracteres',
                              icon: Icons.lock_rounded,
                              obscure: obscure,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _login(),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: _textSecondary.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              ),
                            ),

                            // Error
                            if (widget.store.authError != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xfffff0f0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xffffccd4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffb00020)
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.error_outline,
                                          color: Color(0xffb00020), size: 14),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        widget.store.authError!,
                                        style: const TextStyle(
                                          color: Color(0xffb00020),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 28),

                            // ── Botón Entrar ───────────────────────────────
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [_magenta, _magentaDeep],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _magenta.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: FilledButton.icon(
                                onPressed: loading ? null : _login,
                                icon: loading
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.login_rounded,
                                        size: 20,
                                      ),
                                label: const Text(
                                  'Entrar a nuestro depot',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  minimumSize:
                                      const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Footer sutil
                            Text(
                              'Todo está organizado para que encuentres\nlo que necesitas sin complicaciones ✨',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textSecondary.withValues(alpha: 0.6),
                                fontSize: 11.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDecoShapes() {
    return [
      // Top left blob
      Positioned(
        top: -40,
        left: -30,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _magenta.withValues(alpha: 0.08),
                _magenta.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      // Bottom right blob
      Positioned(
        bottom: -50,
        right: -40,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xffffd54f).withValues(alpha: 0.1),
                const Color(0xffffd54f).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      // Floating hearts
      Positioned(
        top: 80,
        right: 50,
        child: AnimatedBuilder(
          animation: _floatAnim,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _floatAnim.value * 0.6),
            child: Icon(
              Icons.favorite,
              size: 18,
              color: _magenta.withValues(alpha: 0.1),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 120,
        left: 40,
        child: AnimatedBuilder(
          animation: _floatAnim,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, -_floatAnim.value * 0.4),
            child: Icon(
              Icons.favorite,
              size: 12,
              color: _magenta.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _login() async {
    if (username.text.trim().isEmpty || password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Escribe usuario y contraseña válida.')),
      );
      return;
    }
    setState(() => loading = true);
    await widget.store.login(username.text, password.text);
    if (mounted) setState(() => loading = false);
  }
}

// ── Premium text field ─────────────────────────────────────────────────────────
class _PremiumField extends StatelessWidget {
  const _PremiumField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.autofillHints,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xfffff9fc),
        border: Border.all(
          color: const Color(0xffe8d0da).withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffd94f87).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: Color(0xff3a2633),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(icon, size: 20, color: const Color(0xffd94f87)),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: const Color(0xff7a5c6b).withValues(alpha: 0.7),
            fontSize: 13,
          ),
          hintStyle: TextStyle(
            color: const Color(0xff7a5c6b).withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// Pintor de glow suave (rosado)
class _SoftGlowPainter extends CustomPainter {
  const _SoftGlowPainter({required this.color, required this.opacity});
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.4),
        radius: 0.8,
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_SoftGlowPainter old) =>
      old.opacity != opacity || old.color != color;
}

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
    with SingleTickerProviderStateMixin {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  // Paleta CLARO (original)
  static const _magenta = Color(0xffd94f87);
  static const _bgGrad1 = Color(0xffffedf5);
  static const _bgGrad2 = Color(0xfffff8d9);
  static const _bgGrad3 = Color(0xfffffbfd);
  static const _textPrimary = Color(0xff49343f);
  static const _textSecondary = Color(0xff7a5c6b);
  static const _cardBg = Color(0xffffffff);
  static const _stroke = Color(0xffe8d0da);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    _pulse.dispose();
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
            // Glow animado rosa suave
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

            // Contenido principal
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _stroke, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: _magenta.withValues(alpha: 0.08),
                          blurRadius: 32,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mascot
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xffffedf5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _magenta.withValues(alpha: 0.25),
                                  width: 1.5),
                            ),
                            child: const LoveMascot(size: 88),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Título
                        const Text(
                          'My Love Depot',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Nuestro pequeño espacio, hecho con amor para ti 💛',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Todo está organizado para que encuentres lo que necesitas sin complicaciones.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Campo usuario
                        TextField(
                          controller: username,
                          autofillHints: const [AutofillHints.username],
                          style: const TextStyle(color: _textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Tu usuario',
                            hintText: 'Escribe tu usuario',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Campo contraseña
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          onSubmitted: (_) => _login(),
                          autofillHints: const [AutofillHints.password],
                          style: const TextStyle(color: _textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Tu contraseña',
                            hintText: 'Mínimo 8 caracteres',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),

                        // Error
                        if (widget.store.authError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xfffff0f0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xffffccd4), width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xffb00020), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.store.authError!,
                                    style: const TextStyle(
                                      color: Color(0xffb00020),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Botón entrar
                        FilledButton.icon(
                          onPressed: loading ? null : _login,
                          icon: loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.login_rounded),
                          label: const Text('Entrar a nuestro depot'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

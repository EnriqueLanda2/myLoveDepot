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

  static const _magenta = Color(0xffd94f87);
  static const _bgDeep = Color(0xff030507);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.7).animate(
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
      backgroundColor: _bgDeep,
      body: Stack(
        children: [
          // ── Grid background ──────────────────────────────────────────────
          Positioned.fill(child: _GridBackground()),

          // ── Magenta radial glow ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Positioned(
              top: -120,
              left: -100,
              child: Container(
                width: 600,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _magenta.withOpacity(_glow.value * 0.18),
                      Colors.transparent,
                    ],
                    radius: 0.65,
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom accent glow ───────────────────────────────────────────
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 400,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _magenta.withOpacity(0.08),
                    Colors.transparent,
                  ],
                  radius: 0.7,
                ),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // ── Top panel label ──────────────────────────────────
                    _PanelLabel(),
                    const SizedBox(height: 20),

                    // ── Login card ───────────────────────────────────────
                    _LoginCard(
                      store: widget.store,
                      username: username,
                      password: password,
                      loading: loading,
                      obscure: obscure,
                      onToggleObscure: () =>
                          setState(() => obscure = !obscure),
                      onLogin: _login,
                    ),

                    const SizedBox(height: 20),
                    // ── System status strip ──────────────────────────────
                    _StatusStrip(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (username.text.trim().isEmpty || password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe usuario y contraseña válida.')),
      );
      return;
    }
    setState(() => loading = true);
    await widget.store.login(username.text, password.text);
    if (mounted) setState(() => loading = false);
  }
}

// ── Grid background painter ────────────────────────────────────────────────────
class _GridBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0affffff)
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Panel label ────────────────────────────────────────────────────────────────
class _PanelLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          color: const Color(0xffd94f87),
        ),
        const SizedBox(width: 10),
        const Text(
          'SISTEMA DE INVENTARIO  ·  MLD v2.0',
          style: TextStyle(
            color: Color(0xff8892a4),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

// ── Status strip ──────────────────────────────────────────────────────────────
class _StatusStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xff0e1117),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x22ffffff)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xff22c55e),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'SISTEMA OPERATIVO  ·  ACCESO SEGURO HABILITADO',
            style: TextStyle(
              color: Color(0xff8892a4),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Login card ────────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.store,
    required this.username,
    required this.password,
    required this.loading,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final InventoryStore store;
  final TextEditingController username;
  final TextEditingController password;
  final bool loading;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

  static const _magenta = Color(0xffd94f87);
  static const _bgCard = Color(0xff0e1117);
  static const _stroke = Color(0x22ffffff);
  static const _strokeMagenta = Color(0x33d94f87);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _stroke, width: 1),
        boxShadow: [
          BoxShadow(
            color: _magenta.withOpacity(0.06),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header with mascot ─────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mascot in a framed container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff141820),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _strokeMagenta, width: 1),
                ),
                child: const LoveMascot(size: 56),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MY LOVE DEPOT',
                      style: TextStyle(
                        color: Color(0xfff0f2f5),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sistema de gestión de almacén',
                      style: TextStyle(
                        color: Color(0xff8892a4),
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _magenta.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: _magenta.withOpacity(0.3), width: 1),
                      ),
                      child: const Text(
                        '● ACCESO RESTRINGIDO',
                        style: TextStyle(
                          color: _magenta,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          const _SectionDivider(label: 'CREDENCIALES'),
          const SizedBox(height: 20),

          // ── Username ───────────────────────────────────────────────────
          _FieldLabel(label: 'USUARIO'),
          const SizedBox(height: 6),
          TextField(
            controller: username,
            autofillHints: const [AutofillHints.username],
            style: const TextStyle(
              color: Color(0xfff0f2f5),
              fontSize: 14,
              letterSpacing: 0.3,
            ),
            decoration: const InputDecoration(
              hintText: 'Ingresa tu usuario',
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
          ),

          const SizedBox(height: 16),

          // ── Password ───────────────────────────────────────────────────
          _FieldLabel(label: 'CONTRASEÑA'),
          const SizedBox(height: 6),
          TextField(
            controller: password,
            obscureText: obscure,
            onSubmitted: (_) => onLogin(),
            autofillHints: const [AutofillHints.password],
            style: const TextStyle(
              color: Color(0xfff0f2f5),
              fontSize: 14,
              letterSpacing: 0.3,
            ),
            decoration: InputDecoration(
              hintText: 'Mínimo 8 caracteres',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
              ),
            ),
          ),

          // ── Auth error ─────────────────────────────────────────────────
          if (store.authError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xffff5370).withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: const Color(0xffff5370).withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xffff5370), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      store.authError!,
                      style: const TextStyle(
                          color: Color(0xffff5370), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Login button ───────────────────────────────────────────────
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: loading ? null : onLogin,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.login_rounded, size: 18),
              label: Text(
                loading ? 'AUTENTICANDO…' : 'INGRESAR AL SISTEMA',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0x22ffffff))),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xff8892a4),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: const Color(0x22ffffff))),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xff8892a4),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }
}

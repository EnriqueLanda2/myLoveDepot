import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../widgets/love_mascot.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.store, super.key});
  final InventoryStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffffedf5), Color(0xfffff8d9), Color(0xfffffbfd)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: LoveMascot(size: 104)),
                        const SizedBox(height: 16),
                        Text('My Love Depot',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        const Text(
                            'Nuestro pequeño espacio, hecho con amor para ti 💛',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                            'Todo está organizado para que encuentres lo que necesitas sin complicaciones.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 28),
                        TextField(
                          controller: username,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                              labelText: 'Tu usuario',
                              hintText: 'Escribe tu usuario',
                              prefixIcon: Icon(Icons.person)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          onSubmitted: (_) => _login(),
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Tu contraseña',
                            hintText: 'Mínimo 8 caracteres',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              icon: Icon(obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                            ),
                          ),
                        ),
                        if (widget.store.authError != null) ...[
                          const SizedBox(height: 12),
                          Text(widget.store.authError!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: loading ? null : _login,
                          icon: loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.login),
                          label: const Text('Entrar a nuestro depot'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

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

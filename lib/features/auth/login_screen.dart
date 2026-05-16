import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../data/api/api_client.dart';
import '../../data/sync/sync_service.dart';
import 'auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onAuthenticated;

  const LoginScreen({super.key, required this.onAuthenticated});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    if (email.isEmpty || pass.length < 8) {
      setState(() => _error = 'Email y contraseña (≥8) obligatorios');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await ref.read(authProvider.notifier)
            .register(email: email, password: pass);
      } else {
        await ref.read(authProvider.notifier)
            .login(email: email, password: pass);
      }
      // Sync inicial con el token nuevo
      try {
        await ref.read(syncServiceProvider).bootstrapFromServer();
      } catch (_) {}
      if (!mounted) return;
      widget.onAuthenticated();
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.statusCode == 401
            ? 'Email o contraseña incorrectos'
            : e.statusCode == 409
                ? 'Email ya registrado'
                : 'Error ${e.statusCode}';
      });
    } catch (e, st) {
      appLogger.warn('auth', 'Auth error', error: e, stackTrace: st);
      setState(() {
        _busy = false;
        _error = 'Error: $e\n${st.toString().split('\n').take(3).join('\n')}';
      });
    }
  }

  Future<void> _useLegacy() async {
    setState(() => _busy = true);
    // El token legacy ya es el default vía effectiveTokenProvider; solo
    // marcamos auth como inicializado sin sesión y bootstrapeamos.
    try {
      await ref.read(syncServiceProvider).bootstrapFromServer();
    } catch (_) {}
    if (!mounted) return;
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'M',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Memora',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRegister ? 'Crear cuenta' : 'Inicia sesión',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _decor('Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtl,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: _decor('Contraseña'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4F6B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFFF4F6B),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isRegister ? 'Crear cuenta' : 'Entrar',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _isRegister = !_isRegister;
                              _error = null;
                            }),
                    child: Text(
                      _isRegister
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿Sin cuenta? Crear cuenta nueva',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _busy ? null : _useLegacy,
                    icon: const Icon(Icons.fast_forward_rounded, size: 18),
                    label: const Text('Continuar sin login (legacy)'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decor(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1A1A22),
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7C5CFF), width: 1.5),
      ),
    );
  }
}

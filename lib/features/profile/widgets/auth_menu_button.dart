import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

import '../../auth/auth_state.dart';
import '../../auth/login_screen.dart';
import '../../shell/root_shell.dart';

/// Botón de cuenta en el AppBar del perfil: muestra login o popup con logout.
class AuthMenuButton extends ConsumerWidget {
  const AuthMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return PopupMenuButton<String>(
      icon: Icon(
        auth.isLoggedIn ? Icons.account_circle : Icons.login_rounded,
      ),
      tooltip: auth.isLoggedIn ? auth.email ?? 'Cuenta' : 'Iniciar sesión',
      onSelected: (action) async {
        if (action == 'login') {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                onAuthenticated: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RootShell()),
                  (_) => false,
                ),
              ),
            ),
          );
        } else if (action == 'logout') {
          await ref.read(authProvider.notifier).logout();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                onAuthenticated: () =>
                    Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RootShell()),
                  (_) => false,
                ),
              ),
            ),
            (_) => false,
          );
        }
      },
      itemBuilder: (ctx) {
        if (auth.isLoggedIn) {
          return [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.email ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'ID: ${auth.userId ?? ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: ctx.c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: DgtStatusColors.danger),
                  SizedBox(width: 8),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(color: DgtStatusColors.danger),
                  ),
                ],
              ),
            ),
          ];
        }
        return [
          PopupMenuItem(
            enabled: false,
            child: Text(
              'Modo legacy (sin login)',
              style: TextStyle(color: ctx.c.textMuted),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'login',
            child: Row(
              children: [
                Icon(Icons.login_rounded),
                SizedBox(width: 8),
                Text('Iniciar sesión'),
              ],
            ),
          ),
        ];
      },
    );
  }
}

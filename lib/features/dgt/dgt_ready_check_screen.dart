import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dgt_ready_check_provider.dart';

/// Issue #136 (dgt-ux): pantalla "Listo para examen?".
///
/// Self-contained: NO edita home_screen.dart ni dgt_section.dart.
/// Navegacion: `Navigator.push(context, MaterialPageRoute(builder: (_) => const DgtReadyCheckScreen()))`.
class DgtReadyCheckScreen extends ConsumerWidget {
  const DgtReadyCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCheck = ref.watch(dgtReadyCheckProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Listo para examen?')),
      body: asyncCheck.when(
        data: (c) => _Body(check: c),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No se pudo cargar la checklist.'),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.check});

  final DgtReadyCheck check;

  @override
  Widget build(BuildContext context) {
    if (check.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aun no hay suficientes datos para evaluar tu preparacion. '
            'Haz unos simulacros y vuelve aqui.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _VerdictCard(check: check),
        const SizedBox(height: 16),
        ...check.items.map((i) => _CriterionTile(item: i)),
      ],
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.check});

  final DgtReadyCheck check;

  @override
  Widget build(BuildContext context) {
    final color = switch (check.verdict) {
      DgtReadyVerdict.ready => Colors.green,
      DgtReadyVerdict.almost => Colors.amber.shade700,
      DgtReadyVerdict.notReady => Colors.red,
    };
    return Card(
      color: color.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              switch (check.verdict) {
                DgtReadyVerdict.ready => Icons.verified,
                DgtReadyVerdict.almost => Icons.flag,
                DgtReadyVerdict.notReady => Icons.warning,
              },
              color: color,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                check.verdictLabel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriterionTile extends StatelessWidget {
  const _CriterionTile({required this.item});

  final DgtReadyItem item;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (item.status) {
      DgtReadyStatus.pass => Icons.check_circle,
      DgtReadyStatus.warn => Icons.error_outline,
      DgtReadyStatus.fail => Icons.cancel,
    };
    final color = switch (item.status) {
      DgtReadyStatus.pass => Colors.green,
      DgtReadyStatus.warn => Colors.amber.shade700,
      DgtReadyStatus.fail => Colors.red,
    };
    return Card(
      child: ListTile(
        leading: Icon(iconData, color: color),
        title: Text(item.label),
        subtitle: Text(item.detail),
      ),
    );
  }
}

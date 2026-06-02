import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import 'dgt_week_plan_provider.dart';

/// Issue #149 (dgt-ux): pantalla con el plan semanal.
///
/// Renderiza una lista vertical L-D con la meta del dia, badges "HOY"
/// y "SIMULACRO" y un resumen semanal en la parte superior. No edita
/// `home_screen.dart` ni `dgt_section.dart`; se navega manualmente desde
/// `Navigator.push(MaterialPageRoute(builder: (_) => DgtWeekPlanScreen()))`.
class DgtWeekPlanScreen extends ConsumerWidget {
  const DgtWeekPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlan = ref.watch(dgtWeekPlanProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi plan semanal')),
      body: asyncPlan.when(
        data: (plan) => _Body(plan: plan),
        loading: () => AppStateView.loading(),
        error: (_, _) => const _ErrorMessage(),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.plan});

  final DgtWeekPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plan.unconfigured) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Configura la fecha del examen en ajustes para ver tu plan semanal.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Best-effort: si las settings tienen una ruta dedicada
                // distinta, el usuario puede navegar manualmente. Aqui
                // mostramos un snackbar para evitar acoplar a routing.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Abre Ajustes DGT para configurar la fecha'),
                  ),
                );
              },
              child: const Text('Ir a ajustes'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta semana: ${plan.weeklyAnswered}/${plan.weeklyTarget} preguntas '
                    '(${plan.weeklyProgressPercent}%)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: plan.weeklyProgress),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: plan.days.length,
            itemBuilder: (context, i) {
              final d = plan.days[i];
              return _DayTile(day: d);
            },
          ),
        ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});

  final DgtDayPlan day;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];
    if (day.isToday) {
      badges.add(_Badge(label: 'HOY', color: Colors.blue));
    }
    if (day.isSimulacro) {
      badges.add(_Badge(label: 'SIMULACRO', color: Colors.deepPurple));
    }
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            day.isToday ? Colors.blue : Theme.of(context).colorScheme.surface,
        child: Text(
          day.shortLabel,
          style: TextStyle(
            color: day.isToday ? Colors.white : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        day.isSimulacro
            ? 'Simulacro: ${day.target} preguntas'
            : 'Meta: ${day.target} preguntas',
      ),
      subtitle: day.isToday
          ? Text('Hechas hoy: ${day.answered}/${day.target}')
          : null,
      trailing: Wrap(
        spacing: 4,
        children: badges,
      ),
      onTap: () {
        if (day.isToday) {
          // No acoplamos al routing concreto: mostramos snackbar como CTA
          // amistoso. La app ya tiene shortcuts hacia practice/exam desde
          // home y study; este screen no debe duplicar esa navegacion.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                day.isSimulacro
                    ? 'Hoy toca SIMULACRO (${day.target} preg)'
                    : 'Hoy meta: ${day.target} preguntas',
              ),
            ),
          );
        } else if (day.isFuture) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plan: ${day.target} preguntas')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dia ya pasado: objetivo ${day.target}')),
          );
        }
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No se pudo cargar el plan semanal. Intentalo mas tarde.',
        ),
      ),
    );
  }
}

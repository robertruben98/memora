import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../study/dgt_exam_history.dart';
import 'dgt_failures_repository.dart';
import 'dgt_favorites_provider.dart';
import 'dgt_reminder_service.dart';
import 'dgt_settings.dart';
import 'screens/dgt_share_autoescuela_screen.dart';

/// Issue #169 (dgt-ux): pantalla dedicada de Ajustes DGT.
///
/// Concentra controles especificos del flujo de examen (recordatorios,
/// dias activos, modo simulacro estricto, predicciones, reset progreso,
/// export stats). No reemplaza el bloque DGT existente en `settings_screen`,
/// se accede via tile en el Home (`kDgtTileRegistry`).
///
/// Aditivo, sin migraciones destructivas:
/// - `DgtSettings` ya tiene defaults para los campos nuevos.
/// - Recordatorio reutiliza `DgtReminderService` (no se rompe el flujo del
///   issue #102).
/// - Reset usa metodos publicos `clearAll`/`clear` de repos existentes.
class DgtSettingsScreen extends ConsumerWidget {
  const DgtSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(dgtSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes DGT')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => _Body(settings: settings),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final DgtSettings settings;
  const _Body({required this.settings});

  Future<void> _save(WidgetRef ref, DgtSettings next) async {
    await ref.read(dgtSettingsRepositoryProvider).save(next);
    ref.invalidate(dgtSettingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _SectionTitle('Recordatorios'),
        _ReminderTile(settings: settings),
        const SizedBox(height: 8),
        _ReminderDaysTile(
          selected: settings.reminderDays,
          onChanged: (days) => _save(ref, settings.copyWith(reminderDays: days)),
        ),
        const SizedBox(height: 8),
        _StreakReminderModeTile(
          mode: settings.streakReminderMode,
          onChanged: (m) =>
              _save(ref, settings.copyWith(streakReminderMode: m)),
        ),
        const SizedBox(height: 8),
        // Issue #189 (dgt-ux): toggle de notif al alcanzar meta diaria.
        SwitchListTile.adaptive(
          key: const ValueKey('dgt-goal-notif-toggle'),
          contentPadding: EdgeInsets.zero,
          value: settings.goalNotifEnabled,
          onChanged: (v) => _save(ref, settings.copyWith(goalNotifEnabled: v)),
          title: const Text('Notificarme al lograr la meta diaria'),
          subtitle: const Text(
            'Aviso unico al cruzar el umbral. Idempotente por dia.',
          ),
        ),
        const SizedBox(height: 8),
        // Issue #212 (dgt-ux): toggle de alarma anti-perdida de racha.
        SwitchListTile.adaptive(
          key: const ValueKey('dgt-streak-alert-toggle'),
          contentPadding: EdgeInsets.zero,
          value: settings.streakAlertEnabled,
          onChanged: (v) =>
              _save(ref, settings.copyWith(streakAlertEnabled: v)),
          title: const Text('Alarma anti-perdida de racha'),
          subtitle: const Text(
            'Aviso ~1h antes de perder la racha (solo si racha >=3 dias). '
            'Tap = quiz rapido de 5 preguntas.',
          ),
        ),
        const Divider(height: 32),
        _SectionTitle('Simulacro'),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: settings.strictExamMode,
          onChanged: (v) => _save(ref, settings.copyWith(strictExamMode: v)),
          title: const Text('Modo simulacro estricto'),
          subtitle: const Text(
            'Sin pausa, sin revision intermedia, sin volver atras.',
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: settings.showPredictions,
          onChanged: (v) => _save(ref, settings.copyWith(showPredictions: v)),
          title: const Text('Mostrar predicciones'),
          subtitle: const Text(
            'Muestra el tile predictor de aprobacion en el inicio.',
          ),
        ),
        const Divider(height: 32),
        _SectionTitle('Compartir'),
        ListTile(
          key: const Key('dgt-settings-share-autoescuela'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.qr_code_2_rounded),
          title: const Text('Compartir con autoescuela'),
          subtitle: const Text(
            'Genera QR + deeplink con resumen de progreso (sin datos sensibles).',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DgtShareAutoescuelaScreen(),
              ),
            );
          },
        ),
        const Divider(height: 32),
        _SectionTitle('Datos'),
        const _ExportStatsButton(),
        const Divider(height: 32),
        _SectionTitle('Reset selectivo'),
        const _SelectiveResetTile(
          kind: _SelectiveResetKind.failures,
        ),
        const SizedBox(height: 4),
        const _SelectiveResetTile(
          kind: _SelectiveResetKind.favorites,
        ),
        const SizedBox(height: 4),
        const _SelectiveResetTile(
          kind: _SelectiveResetKind.examHistory,
        ),
        const SizedBox(height: 4),
        const _SelectiveResetTile(
          kind: _SelectiveResetKind.streak,
        ),
        const SizedBox(height: 16),
        const _ResetProgressButton(),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Issue #202 (dgt-ux): tipos de reset selectivo. Cada uno aisla un store
/// distinto para que el usuario no pierda TODO al limpiar solo una parte.
enum _SelectiveResetKind {
  failures,
  favorites,
  examHistory,
  streak,
}

extension _SelectiveResetKindX on _SelectiveResetKind {
  String get title {
    switch (this) {
      case _SelectiveResetKind.failures:
        return 'Borrar fallos registrados';
      case _SelectiveResetKind.favorites:
        return 'Borrar favoritas';
      case _SelectiveResetKind.examHistory:
        return 'Borrar historial de simulacros';
      case _SelectiveResetKind.streak:
        return 'Reiniciar racha';
    }
  }

  String get subtitle {
    switch (this) {
      case _SelectiveResetKind.failures:
        return 'Limpia cola de fallos recientes. NO afecta favoritas, '
            'simulacros ni racha.';
      case _SelectiveResetKind.favorites:
        return 'Limpia tu set de preguntas marcadas. NO afecta fallos, '
            'simulacros ni racha.';
      case _SelectiveResetKind.examHistory:
        return 'Borra historial de simulacros. NO afecta fallos, favoritas '
            'ni racha.';
      case _SelectiveResetKind.streak:
        return 'Resetea contador diario (racha = 0). NO borra respuestas, '
            'favoritas ni simulacros.';
    }
  }

  String get confirmBody {
    switch (this) {
      case _SelectiveResetKind.failures:
        return 'Se borrara la cola de fallos recientes.\n\n'
            'Se conservan: favoritas, historial de simulacros, racha, '
            'ajustes.';
      case _SelectiveResetKind.favorites:
        return 'Se borrara tu set de preguntas favoritas.\n\n'
            'Se conservan: fallos, historial de simulacros, racha, ajustes.';
      case _SelectiveResetKind.examHistory:
        return 'Se borrara el historial de simulacros.\n\n'
            'Se conservan: fallos, favoritas, racha, ajustes.';
      case _SelectiveResetKind.streak:
        return 'Se resetea el contador de respuestas de hoy (la racha '
            'vuelve a 0).\n\nSe conservan: fallos, favoritas, historial '
            'de simulacros, ajustes.';
    }
  }

  String get keySuffix {
    switch (this) {
      case _SelectiveResetKind.failures:
        return 'failures';
      case _SelectiveResetKind.favorites:
        return 'favorites';
      case _SelectiveResetKind.examHistory:
        return 'exam-history';
      case _SelectiveResetKind.streak:
        return 'streak';
    }
  }

  IconData get icon {
    switch (this) {
      case _SelectiveResetKind.failures:
        return Icons.error_outline_rounded;
      case _SelectiveResetKind.favorites:
        return Icons.star_border_rounded;
      case _SelectiveResetKind.examHistory:
        return Icons.history_rounded;
      case _SelectiveResetKind.streak:
        return Icons.local_fire_department_outlined;
    }
  }

  String get successMsg {
    switch (this) {
      case _SelectiveResetKind.failures:
        return 'Fallos borrados';
      case _SelectiveResetKind.favorites:
        return 'Favoritas borradas';
      case _SelectiveResetKind.examHistory:
        return 'Historial de simulacros borrado';
      case _SelectiveResetKind.streak:
        return 'Racha reiniciada';
    }
  }
}

/// Tile generico de reset selectivo. UI consistente entre las 4 acciones.
class _SelectiveResetTile extends ConsumerWidget {
  final _SelectiveResetKind kind;
  const _SelectiveResetTile({required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: ValueKey('dgt-selective-reset-${kind.keySuffix}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(kind.icon, color: const Color(0xFFFF9F43)),
      title: Text(kind.title),
      subtitle: Text(
        kind.subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _confirmAndRun(context, ref),
    );
  }

  Future<void> _confirmAndRun(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind.title),
        content: Text(kind.confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: ValueKey('selective-reset-confirm-${kind.keySuffix}'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF5C5C),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await _runSelectiveReset(ref, kind);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kind.successMsg)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

/// Issue #202 (dgt-ux): logica pura de reset selectivo. Extraida del widget
/// para permitir tests sin levantar UI. Cada branch toca un unico store:
/// GARANTIZA aislamiento (criterio del acceptance).
Future<void> _runSelectiveReset(
  WidgetRef ref,
  _SelectiveResetKind kind,
) async {
  switch (kind) {
    case _SelectiveResetKind.failures:
      await ref.read(dgtFailuresRepositoryProvider).clearAll();
      ref.invalidate(dgtRecentFailuresProvider);
      ref.invalidate(dgtRecentFailuresCountProvider);
      break;
    case _SelectiveResetKind.favorites:
      await ref.read(dgtFavoritesProvider.notifier).clearAll();
      break;
    case _SelectiveResetKind.examHistory:
      await ref.read(dgtExamHistoryRepositoryProvider).clear();
      ref.invalidate(dgtExamHistoryProvider);
      break;
    case _SelectiveResetKind.streak:
      // Racha se computa desde answered-today + failures. Para reiniciar SIN
      // tocar fallos, limpiamos solo los contadores diarios persistidos.
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
            (k) => k.startsWith(kDgtAnsweredTodayPrefix),
          );
      for (final k in keys) {
        await prefs.remove(k);
      }
      break;
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF9FA6BC),
        ),
      ),
    );
  }
}

/// Toggle recordatorio + hora. Reutiliza `DgtReminderService`.
class _ReminderTile extends ConsumerWidget {
  final DgtSettings settings;
  const _ReminderTile({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfgAsync = ref.watch(dgtReminderConfigProvider);
    return cfgAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (cfg) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: cfg.enabled,
              onChanged: (v) async {
                final service = ref.read(dgtReminderServiceProvider);
                if (v) {
                  final ok = await service.requestPermissionsIfNeeded();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Permiso de notificaciones denegado.',
                        ),
                      ),
                    );
                    return;
                  }
                }
                final next = cfg.copyWith(enabled: v);
                await service.saveConfig(next);
                await service.reschedule(next, examDate: settings.examDate);
                ref.invalidate(dgtReminderConfigProvider);
              },
              title: const Text('Recordatorio diario'),
              subtitle: Text(
                cfg.enabled
                    ? 'Activo a las ${cfg.label}'
                    : 'Apagado',
              ),
            ),
            if (cfg.enabled)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay(hour: cfg.hour, minute: cfg.minute),
                    );
                    if (picked == null) return;
                    final service = ref.read(dgtReminderServiceProvider);
                    final next = cfg.copyWith(
                      hour: picked.hour,
                      minute: picked.minute,
                    );
                    await service.saveConfig(next);
                    await service.reschedule(
                      next,
                      examDate: settings.examDate,
                    );
                    ref.invalidate(dgtReminderConfigProvider);
                  },
                  icon: const Icon(Icons.access_time_rounded, size: 18),
                  label: Text('Hora: ${cfg.label}'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Selector multi-toggle de dias activos (L-D). ISO: 1=Lun..7=Dom.
class _ReminderDaysTile extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  const _ReminderDaysTile({required this.selected, required this.onChanged});

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Dias activos',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Wrap(
          spacing: 6,
          children: List.generate(7, (i) {
            final day = i + 1;
            final isOn = selected.contains(day);
            return FilterChip(
              key: ValueKey('reminder-day-$day'),
              label: Text(_labels[i]),
              selected: isOn,
              onSelected: (v) {
                final next = List<int>.from(selected);
                if (v) {
                  if (!next.contains(day)) next.add(day);
                } else {
                  next.remove(day);
                }
                next.sort();
                // Garantia: al menos 1 dia. Si vacian todo, restauramos
                // el dia que tocaron (no permitir lista vacia).
                if (next.isEmpty) next.add(day);
                onChanged(next);
              },
            );
          }),
        ),
      ],
    );
  }
}

/// Selector de modo de recordatorio de racha.
class _StreakReminderModeTile extends StatelessWidget {
  final DgtStreakReminderMode mode;
  final ValueChanged<DgtStreakReminderMode> onChanged;
  const _StreakReminderModeTile({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6, top: 4),
          child: Text(
            'Frecuencia recordatorios racha',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        RadioGroup<DgtStreakReminderMode>(
          groupValue: mode,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          child: Column(
            children: [
              for (final m in DgtStreakReminderMode.values)
                ListTile(
                  key: ValueKey('streak-mode-${m.code}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Radio<DgtStreakReminderMode>(value: m),
                  title: Text(m.label),
                  subtitle: Text(
                    m.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => onChanged(m),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Boton "Exportar mis stats DGT". Reune settings + historial + fallos
/// recientes en JSON y comparte via share_plus.
class _ExportStatsButton extends ConsumerWidget {
  const _ExportStatsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('dgt-export-stats'),
        onPressed: () => _export(context, ref),
        icon: const Icon(Icons.ios_share_rounded, size: 18),
        label: const Text('Exportar mis stats DGT'),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final settings = await ref.read(dgtSettingsRepositoryProvider).load();
      final history =
          await ref.read(dgtExamHistoryRepositoryProvider).load();
      final failures =
          await ref.read(dgtFailuresRepositoryProvider).recentFailures();
      final payload = <String, dynamic>{
        'exported_at': DateTime.now().toIso8601String(),
        'settings': <String, dynamic>{
          'license_type': settings.licenseType.code,
          'exam_date': settings.examDate?.toIso8601String(),
          'daily_goal': settings.dailyGoal,
          'reminder_days': settings.reminderDays,
          'streak_reminder_mode': settings.streakReminderMode.code,
          'strict_exam_mode': settings.strictExamMode,
          'show_predictions': settings.showPredictions,
        },
        'exam_history': history
            .map((e) => <String, dynamic>{
                  'date': e.date.toIso8601String(),
                  'correct': e.correct,
                  'total': e.total,
                  'time_used_sec': e.timeUsed.inSeconds,
                  'passed': e.passed,
                })
            .toList(),
        'recent_failures': failures
            .map((f) => <String, dynamic>{
                  'question_id': f.question.id,
                  'failed_at': f.failedAt.toIso8601String(),
                })
            .toList(),
      };
      final encoder = const JsonEncoder.withIndent('  ');
      final json = encoder.convert(payload);
      await Share.share(json, subject: 'Mis stats DGT (RutaB)');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar: $e')),
      );
    }
  }
}

/// Reset progreso DGT con DOBLE confirmacion (criterio del issue).
class _ResetProgressButton extends ConsumerWidget {
  const _ResetProgressButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('dgt-reset-progress'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF5C5C),
          side: const BorderSide(color: Color(0xFFFF5C5C)),
        ),
        onPressed: () => _confirmAndReset(context, ref),
        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
        label: const Text('Resetear progreso DGT'),
      ),
    );
  }

  Future<void> _confirmAndReset(BuildContext context, WidgetRef ref) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetear progreso DGT'),
        content: const Text(
          'Esto borrara:\n'
          '- Historial de simulacros\n'
          '- Cola de fallos recientes\n'
          '- Racha y contadores diarios\n\n'
          'Tus ajustes (licencia, meta, recordatorios) se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('reset-confirm-1'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reset'),
        content: const Text(
          'Esta accion no se puede deshacer. ?Seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('reset-confirm-2'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF5C5C),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;
    try {
      await ref.read(dgtExamHistoryRepositoryProvider).clear();
      await ref.read(dgtFailuresRepositoryProvider).clearAll();
      // Limpiar contadores diarios + cache de meta (best-effort).
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
            (k) => k.startsWith(kDgtAnsweredTodayPrefix),
          );
      for (final k in keys) {
        await prefs.remove(k);
      }
      // Invalida providers afectados para refrescar UI.
      ref.invalidate(dgtExamHistoryProvider);
      ref.invalidate(dgtRecentFailuresProvider);
      ref.invalidate(dgtRecentFailuresCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progreso DGT reseteado')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reseteando: $e')),
      );
    }
  }
}

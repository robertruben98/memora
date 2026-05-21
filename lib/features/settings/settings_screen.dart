import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/srs/study_settings.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/backup/backup_service.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';
import '../../data/repositories/dgt_repository.dart';
import '../dgt/dgt_reminder_service.dart';
import '../dgt/dgt_settings.dart';
import '../dgt/services/dgt_backup_service.dart';
import '../home/welcome_tour.dart';
import '../review/study_queue.dart';
import '../stats/stats_repository.dart';
import 'settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final study = ref.watch(studySettingsProvider);
    final theme = ref.watch(themeModeProvider);
    final dgtAsync = ref.watch(dgtSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ajustes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          const _SectionTitle('Estudio'),
          const SizedBox(height: 8),
          _SliderSetting(
            label: 'Tarjetas nuevas por día',
            value: study.newCardsPerDay.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            valueLabel: '${study.newCardsPerDay}',
            onChanged: (v) async {
              final newSettings =
                  study.copyWith(newCardsPerDay: v.round());
              ref.read(studySettingsProvider.notifier).state = newSettings;
              await ref
                  .read(settingsRepositoryProvider)
                  .saveStudySettings(newSettings);
              ref.invalidate(studyQueueProvider(null));
            },
          ),
          const SizedBox(height: 12),
          _SliderSetting(
            label: 'Revisiones máximas por día',
            value: study.maxReviewsPerDay.toDouble(),
            min: 10,
            max: 200,
            divisions: 19,
            valueLabel: '${study.maxReviewsPerDay}',
            onChanged: (v) async {
              final newSettings = study.copyWith(maxReviewsPerDay: v.round());
              ref.read(studySettingsProvider.notifier).state = newSettings;
              await ref
                  .read(settingsRepositoryProvider)
                  .saveStudySettings(newSettings);
              ref.invalidate(studyQueueProvider(null));
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle('DGT'),
          const SizedBox(height: 8),
          dgtAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (dgt) => _DgtSection(
              settings: dgt,
              onChanged: (next) async {
                await ref.read(dgtSettingsRepositoryProvider).save(next);
                ref.invalidate(dgtSettingsProvider);
              },
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Apariencia'),
          const SizedBox(height: 8),
          _ThemeSelector(
            selected: theme,
            onChanged: (m) async {
              ref.read(themeModeProvider.notifier).state = m;
              await ref.read(settingsRepositoryProvider).saveThemeMode(m);
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Backup'),
          const SizedBox(height: 8),
          _ActionCard(
            icon: Icons.upload_rounded,
            color: const Color(0xFF4F8AFF),
            title: 'Exportar copia (JSON)',
            description:
                'Descarga todos tus mazos, tarjetas y progreso. '
                'Las imágenes no se incluyen.',
            onTap: () => _exportBackup(context, ref),
          ),
          const SizedBox(height: 8),
          _ActionCard(
            icon: Icons.download_rounded,
            color: const Color(0xFF4FFFB0),
            title: 'Importar copia (JSON)',
            description:
                'Reemplaza el contenido actual con un backup. '
                'Confirmación requerida.',
            onTap: () => _importBackup(context, ref),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Datos'),
          const SizedBox(height: 8),
          _DangerCard(
            icon: Icons.refresh_rounded,
            title: 'Resetear progreso SRS',
            description:
                'Borra todas las programaciones y el historial de '
                'revisiones. Las tarjetas y mazos quedan intactos.',
            onTap: () => _confirmReset(context, ref),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Acerca de'),
          const SizedBox(height: 8),
          const _AboutCard(),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(backupServiceProvider).exportAndShare();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exportando: $e')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text('¿Reemplazar contenido?'),
        content: const Text(
          'Importar un backup borra TODOS tus mazos, tarjetas y '
          'progreso actuales antes de cargar los del archivo. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4F6B),
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final result = await ref
          .read(backupServiceProvider)
          .importFromFilePicker(replace: true);
      if (result == null) return;

      ref.invalidate(deckSummariesProvider);
      ref.invalidate(allCardsProvider);
      ref.invalidate(studyQueueProvider(null));
      ref.invalidate(statsSnapshotProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importado: ${result.decks} mazos, '
            '${result.cards} tarjetas, ${result.logs} reviews',
          ),
          backgroundColor: const Color(0xFF4FFFB0),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importando: $e')),
      );
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text('¿Resetear progreso?'),
        content: const Text(
          'Vas a borrar tu historial de estudio: todas las '
          'programaciones SRS y los logs de revisiones. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF4F6B),
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (ok1 != true || !context.mounted) return;

    final ok2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text('¿Estás seguro?'),
        content: const Text(
          'Última confirmación. Toca "Sí, resetear" para borrar '
          'definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4F6B),
            ),
            child: const Text('Sí, resetear'),
          ),
        ],
      ),
    );
    if (ok2 != true || !context.mounted) return;

    await ref.read(settingsRepositoryProvider).resetSrsProgress();

    ref.invalidate(deckSummariesProvider);
    ref.invalidate(allCardsProvider);
    ref.invalidate(studyQueueProvider(null));
    ref.invalidate(statsSnapshotProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progreso reseteado'),
        backgroundColor: Color(0xFF4FFFB0),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  valueLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C5CFF),
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _option(ThemeMode.light, Icons.light_mode_rounded, 'Claro'),
          _option(ThemeMode.dark, Icons.dark_mode_rounded, 'Oscuro'),
          _option(ThemeMode.system, Icons.smartphone_rounded, 'Sistema'),
        ],
      ),
    );
  }

  Widget _option(ThemeMode mode, IconData icon, String label) {
    final active = selected == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF7C5CFF).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: active
                    ? const Color(0xFF7C5CFF)
                    : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? const Color(0xFF7C5CFF)
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _DangerCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF4F6B).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4F6B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFFF4F6B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF4F6B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DgtSection extends StatelessWidget {
  final DgtSettings settings;
  final ValueChanged<DgtSettings> onChanged;

  const _DgtSection({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permiso',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DgtLicenseType.values
                .map(
                  (t) => ChoiceChip(
                    label: Text('${t.code} - ${t.shortLabel}'),
                    selected: settings.licenseType == t,
                    onSelected: (_) =>
                        onChanged(settings.copyWith(licenseType: t)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Fecha examen',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: settings.examDate ??
                          now.add(const Duration(days: 30)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      onChanged(settings.copyWith(examDate: picked));
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    settings.examDate == null
                        ? 'Elegir fecha'
                        : '${settings.examDate!.day}/'
                            '${settings.examDate!.month}/'
                            '${settings.examDate!.year}',
                  ),
                ),
              ),
              if (settings.examDate != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: 'Quitar fecha',
                  onPressed: () =>
                      onChanged(settings.copyWith(clearExamDate: true)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Meta diaria de preguntas',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [10, 20, 30, 50]
                .map(
                  (n) => ChoiceChip(
                    label: Text('$n'),
                    selected: settings.dailyGoal == n,
                    onSelected: (_) =>
                        onChanged(settings.copyWith(dailyGoal: n)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          // DGT issue #84: boton para volver a ver el tour de bienvenida.
          const _DgtTourRelaunchButton(),
          const SizedBox(height: 12),
          // DGT issue #42: toggle del modal explicativo al fallar.
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.showExplanationOnFail,
            onChanged: (v) =>
                onChanged(settings.copyWith(showExplanationOnFail: v)),
            title: const Text(
              'Mostrar explicacion al fallar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Al marcar una tarjeta como incorrecta, muestra un panel '
              'con la normativa y la respuesta correcta antes de avanzar.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.35,
              ),
            ),
            activeThumbColor: const Color(0xFF7C5CFF),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.4),
          const SizedBox(height: 12),
          // DGT issue #102 (dgt-ux): recordatorio diario meta DGT.
          _DgtReminderTile(examDate: settings.examDate, dailyGoal: settings.dailyGoal),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.4),
          const SizedBox(height: 12),
          // DGT issue #45: boton para sincronizar/invalidar cache del banco DGT.
          const _DgtSyncButton(),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.4),
          const SizedBox(height: 12),
          // DGT issue #175: export/import progreso DGT (JSON local).
          const _DgtBackupTile(),
        ],
      ),
    );
  }
}

/// Boton "Sincronizar banco DGT" (issue #45).
///
/// Invalida la cache local de preguntas DGT y dispara un refetch al backend
/// la proxima vez que se abra el simulacro. Util si el usuario sospecha que
/// el banco esta desactualizado (>7 dias) o quiere forzar version nueva.
class _DgtSyncButton extends ConsumerStatefulWidget {
  const _DgtSyncButton();

  @override
  ConsumerState<_DgtSyncButton> createState() => _DgtSyncButtonState();
}

class _DgtSyncButtonState extends ConsumerState<_DgtSyncButton> {
  bool _syncing = false;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final repo = ref.read(dgtRepositoryProvider);
      await repo.invalidateCache();
      // Pre-fetch para tener el banco fresco listo en el proximo simulacro
      // (best-effort: si falla offline, la cache queda vacia y se reintentara).
      await repo.fetchExamQuestions(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banco DGT sincronizado'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo sincronizar (sin conexion)'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _syncing ? null : _sync,
        icon: _syncing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded, size: 18),
        label: Text(_syncing ? 'Sincronizando...' : 'Sincronizar banco DGT'),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'M',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Memora',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'v0.10.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Aprende cualquier cosa con repetición espaciada en formato '
            'feed. Algoritmo SM-2, almacenamiento local, sin tracking.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Boton "Ver tour de nuevo" en Ajustes (issue #84).
///
/// Resetea la flag `dgt_tour_completed` a false. La proxima vez que el
/// usuario abra Home, el tour se mostrara automaticamente.
class _DgtTourRelaunchButton extends ConsumerWidget {
  const _DgtTourRelaunchButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await setDgtTourCompleted(ref, false);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tour reseteado. Se mostrara al abrir Inicio.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.tour_rounded, size: 18),
        label: const Text('Ver tour de bienvenida'),
      ),
    );
  }
}

/// Issue #102 (dgt-ux): tile en Ajustes DGT para activar/desactivar el
/// recordatorio diario y elegir la hora. Persiste en SharedPreferences via
/// [DgtReminderService] y reprograma al cambiar.
class _DgtReminderTile extends ConsumerWidget {
  final DateTime? examDate;
  final int dailyGoal;

  const _DgtReminderTile({required this.examDate, required this.dailyGoal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfgAsync = ref.watch(dgtReminderConfigProvider);
    return cfgAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text('Recordatorio: error ($e)'),
      data: (cfg) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: cfg.enabled,
              onChanged: (v) async {
                final service = ref.read(dgtReminderServiceProvider);
                // Si lo activa, pedir permisos (Android 13+/iOS).
                bool ok = true;
                if (v) {
                  ok = await service.requestPermissionsIfNeeded();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Permiso de notificaciones denegado. Actívalo en Ajustes del sistema.',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    // No persistimos enabled=true sin permiso.
                    return;
                  }
                }
                // Sincronizar meta y fecha cacheadas para el chequeo
                // de meta cumplida.
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt(kDgtDailyGoalLocalKey, dailyGoal);
                if (examDate != null) {
                  await prefs.setString(
                    kDgtExamDateLocalKey,
                    examDate!.toIso8601String(),
                  );
                } else {
                  await prefs.remove(kDgtExamDateLocalKey);
                }
                final next = cfg.copyWith(enabled: v);
                await service.saveConfig(next);
                await service.reschedule(next, examDate: examDate);
                ref.invalidate(dgtReminderConfigProvider);
              },
              title: const Text(
                'Recordatorio diario',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                cfg.enabled
                    ? 'Aviso diario a las ${cfg.label} para cumplir tu meta DGT.'
                    : 'Activa una notificacion diaria para no perder la racha.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.35,
                ),
              ),
              activeThumbColor: const Color(0xFF7C5CFF),
            ),
            if (cfg.enabled) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: cfg.hour, minute: cfg.minute),
                  );
                  if (picked == null) return;
                  final next = cfg.copyWith(
                    hour: picked.hour,
                    minute: picked.minute,
                  );
                  final service = ref.read(dgtReminderServiceProvider);
                  await service.saveConfig(next);
                  await service.reschedule(next, examDate: examDate);
                  ref.invalidate(dgtReminderConfigProvider);
                },
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text('Hora: ${cfg.label}'),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Issue #175 (dgt-ux): export/import del progreso DGT (favoritas, fallos,
/// historiales, settings) como JSON local. Compartible via share_plus,
/// restorable via file_picker. Merge: union para favoritas/fallos, max(streak),
/// keep newest para examDate/settings (ver `mergePayloads`).
class _DgtBackupTile extends ConsumerStatefulWidget {
  const _DgtBackupTile();

  @override
  ConsumerState<_DgtBackupTile> createState() => _DgtBackupTileState();
}

class _DgtBackupTileState extends ConsumerState<_DgtBackupTile> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final svc = ref.read(dgtBackupServiceProvider);
      await svc.exportAndShare();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Progreso exportado'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo exportar el progreso'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final svc = ref.read(dgtBackupServiceProvider);
      final result = await svc.pickAndRead();
      if (!mounted) return;
      if (result.cancelled) return;
      if (!result.isOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Archivo invalido'),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      final payload = result.payload!;
      // Confirmacion pre-merge.
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restaurar progreso DGT'),
          content: Text(
            'Se va a mezclar con tu progreso actual:\n\n'
            '${payload.summaryLabel}\n\n'
            'Estrategia: favoritas y fallos se unifican, racha gana la mayor, '
            'fecha de examen y meta usan los del backup mas reciente. '
            'No se borra nada de lo que ya tienes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final merged = await svc.applyMerge(payload);
      if (!mounted) return;
      // Refrescar providers afectados.
      ref.invalidate(dgtSettingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Progreso restaurado: ${merged.summaryLabel}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo restaurar el progreso'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Copia de seguridad del progreso DGT',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Exporta tus favoritas, fallos, racha y simulacros a un JSON '
          'que puedes guardar en Drive/email/WhatsApp y restaurar en otro '
          'movil o tras reinstalar.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _export,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Exportar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Importar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

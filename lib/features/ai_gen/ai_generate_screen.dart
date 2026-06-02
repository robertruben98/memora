import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';

import '../../core/theme/deck_visuals.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';
import '../../data/sync/sync_service.dart';
import '../profile/character_progress.dart';
import '../quest/quest_provider.dart';
import '../review/study_queue.dart';

class AiGenerateScreen extends ConsumerStatefulWidget {
  const AiGenerateScreen({super.key});

  @override
  ConsumerState<AiGenerateScreen> createState() => _AiGenerateScreenState();
}

class _AiGenerateScreenState extends ConsumerState<AiGenerateScreen> {
  final _topicCtl = TextEditingController();
  int _count = 15;
  String _language = 'español';
  String _colorHex = DeckVisuals.palette.first;
  final String _iconName = 'auto_awesome_rounded';
  bool _generating = false;
  String? _error;
  bool? _aiConfigured;

  @override
  void initState() {
    super.initState();
    _checkAiStatus();
  }

  Future<void> _checkAiStatus() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/ai/status');
      if (!mounted) return;
      setState(() => _aiConfigured = (res as Map)['configured'] as bool);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiConfigured = false;
        _error = 'No se pudo conectar al servidor: $e';
      });
    }
  }

  @override
  void dispose() {
    _topicCtl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicCtl.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = 'Escribe el tema del mazo');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/decks/generate', {
        'topic': topic,
        'count': _count,
        'language': _language,
        'color_hex': _colorHex,
        'icon_name': _iconName,
      });
      // Re-sync para que el cache local refleje el nuevo mazo
      await ref.read(syncServiceProvider).bootstrapFromServer();
      if (!mounted) return;
      ref.invalidate(deckSummariesProvider);
      ref.invalidate(allCardsProvider);
      ref.invalidate(studyQueueProvider(null));
      ref.invalidate(characterProgressProvider);
      ref.invalidate(dailyQuestProvider);

      final count = (res as Map)['generated_count'] as int;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generadas $count tarjetas'),
          backgroundColor: const Color(0xFF4FFFB0),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _generating = false;
        _error = e.statusCode == 503
            ? 'Configura ANTHROPIC_API_KEY en el backend'
            : 'Error ${e.statusCode}: ${e.body}';
      });
    } catch (e) {
      setState(() {
        _generating = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = DeckVisuals.colorFromHex(_colorHex);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Generar con IA',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _generating,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Hero(),
            const SizedBox(height: 20),
            if (_aiConfigured == false) const _AiNotConfiguredBanner(),
            if (_aiConfigured == false) const SizedBox(height: 16),
            const _Label('Tema'),
            const SizedBox(height: 6),
            _Field(
              controller: _topicCtl,
              hint: 'p. ej. "Kubernetes para principiantes" o '
                  '"Vocabulario de viajes en alemán"',
              maxLines: 2,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Cantidad'),
                      const SizedBox(height: 6),
                      _Counter(
                        value: _count,
                        min: 5,
                        max: 30,
                        onChanged: (v) => setState(() => _count = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Idioma'),
                      const SizedBox(height: 6),
                      _LangPicker(
                        value: _language,
                        onChanged: (v) => setState(() => _language = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _Label('Color del mazo'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in DeckVisuals.palette)
                  GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DeckVisuals.colorFromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hex == _colorHex
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4F6B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF4F6B).withValues(alpha: 0.4),
                  ),
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generating || _aiConfigured == false
                  ? null
                  : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_generating
                  ? 'Generando con Claude…'
                  : 'Generar mazo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: color,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Las tarjetas se generan con Claude y se guardan en tu '
                'mazo. Tarda ~5-15s según la cantidad.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.c.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE04FFF), Color(0xFF7C5CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Genera un mazo con IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dale un tema y Claude crea las tarjetas por ti',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiNotConfiguredBanner extends StatelessWidget {
  const _AiNotConfiguredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD24F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD24F).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD24F)),
              SizedBox(width: 8),
              Text(
                'IA no configurada',
                style: TextStyle(
                  color: Color(0xFFFFD24F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'El backend necesita ANTHROPIC_API_KEY. En el server:\n'
            'edita /home/robertdev/memora-backend/.env, añade tu '
            'clave (sk-ant-...) y reinicia con\n'
            'docker compose up -d --build',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: context.c.textMuted,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.c.textMuted),
        filled: true,
        fillColor: context.c.surfaceElevated,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.c.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 5) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 5) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _LangPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LangPicker({required this.value, required this.onChanged});

  static const _options = ['español', 'english', 'français', 'deutsch'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: context.c.surfaceElevated,
          style: TextStyle(fontSize: 14, color: context.c.textPrimary),
          items: [
            for (final o in _options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

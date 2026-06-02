import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/api/api_client.dart';

/// Catalogo visual de senales de trafico DGT (issue #109).
///
/// Pantalla aditiva accesible desde `DgtStudySection` (study hub). Consume el
/// endpoint backend `GET /dgt/signs` (ya disponible, 59 senales) y muestra
/// una grilla 3 columnas con imagen + nombre corto.
///
/// Funcionalidades:
/// - Filtros por categoria (Chips): Peligro / Prohibicion / Obligacion /
///   Indicacion (las categorias se infieren dinamicamente del endpoint).
/// - Buscador simple por nombre / codigo.
/// - Tap en senal abre bottom sheet con descripcion ampliada.
///
/// Resilient: si la imagen SVG no resuelve (e.g. estaticos aun no servidos),
/// degrada a un badge estilizado con el codigo de la senal. Cero crash.
class DgtSignalsCatalogScreen extends ConsumerStatefulWidget {
  const DgtSignalsCatalogScreen({super.key});

  @override
  ConsumerState<DgtSignalsCatalogScreen> createState() =>
      _DgtSignalsCatalogScreenState();
}

class _DgtSignalsCatalogScreenState
    extends ConsumerState<DgtSignalsCatalogScreen> {
  String _selectedCategory = 'todas';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signsAsync = ref.watch(dgtSignsCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogo de senales'),
      ),
      body: signsAsync.when(
        loading: () => AppStateView.loading(),
        error: (e, _) => AppStateView.error(e),
        data: (signs) {
          if (signs.isEmpty) {
            return const Center(child: Text('Catalogo vacio.'));
          }
          final categories = _categoriesFromSigns(signs);
          final filtered = _applyFilters(signs);
          return Column(
            children: [
              _SearchBar(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
              _CategoryChips(
                categories: categories,
                selected: _selectedCategory,
                onSelect: (c) => setState(() => _selectedCategory = c),
              ),
              if (filtered.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Sin resultados'),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final sign = filtered[i];
                      return _SignTile(
                        sign: sign,
                        onTap: () => _openSignSheet(context, sign),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<DgtSign> _applyFilters(List<DgtSign> signs) {
    final q = _searchQuery.toLowerCase();
    return signs.where((s) {
      final matchesCategory = _selectedCategory == 'todas' ||
          s.category.toLowerCase() == _selectedCategory.toLowerCase();
      if (!matchesCategory) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q);
    }).toList();
  }

  List<String> _categoriesFromSigns(List<DgtSign> signs) {
    final set = <String>{};
    for (final s in signs) {
      if (s.category.isNotEmpty) set.add(s.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  void _openSignSheet(BuildContext context, DgtSign sign) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SignDetailSheet(sign: sign),
    );
  }
}

/// Modelo simple de senal DGT consumida desde `GET /dgt/signs`.
class DgtSign {
  final String code;
  final String name;
  final String category;
  final String imageUrl;
  final String meaning;

  const DgtSign({
    required this.code,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.meaning,
  });

  factory DgtSign.fromJson(Map<String, dynamic> j) {
    return DgtSign(
      code: (j['code'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      imageUrl: (j['image_url'] ?? '').toString(),
      meaning: (j['meaning'] ?? '').toString(),
    );
  }
}

/// Carga el catalogo de senales desde backend. Cachea con AsyncNotifier
/// nativo: una sola request mientras la pantalla este montada.
final dgtSignsCatalogProvider =
    FutureProvider<List<DgtSign>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final raw = await api.get('/dgt/signs');
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => DgtSign.fromJson(Map<String, dynamic>.from(m)))
      .toList();
});

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar senal por nombre o codigo (ej. R-301)',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: context.c.surfaceElevated,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final all = ['todas', ...categories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = all[i];
          final isSel = c == selected;
          return ChoiceChip(
            label: Text(_labelFor(c)),
            selected: isSel,
            onSelected: (_) => onSelect(c),
          );
        },
      ),
    );
  }

  String _labelFor(String c) {
    switch (c) {
      case 'todas':
        return 'Todas';
      case 'peligro':
        return 'Peligro';
      case 'prohibicion':
        return 'Prohibicion';
      case 'obligacion':
        return 'Obligacion';
      case 'indicacion':
        return 'Indicacion';
      default:
        // capitalize fallback
        if (c.isEmpty) return c;
        return c[0].toUpperCase() + c.substring(1);
    }
  }
}

class _SignTile extends ConsumerWidget {
  final DgtSign sign;
  final VoidCallback onTap;

  const _SignTile({required this.sign, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.c.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _SignImage(sign: sign),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sign.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignImage extends ConsumerWidget {
  final DgtSign sign;
  const _SignImage({required this.sign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final url = api.remoteUrlFor(sign.imageUrl) ?? sign.imageUrl;
    final isSvg = url.toLowerCase().endsWith('.svg');
    // Image.network no renderiza SVG. Si el path apunta a .svg degradamos
    // directamente al fallback estilizado (badge con codigo + color por
    // categoria). Asi evitamos un fetch garantizado al fallo.
    if (isSvg || url.isEmpty) {
      return _SignFallbackBadge(sign: sign);
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _SignFallbackBadge(sign: sign),
    );
  }
}

/// Badge visual que se muestra cuando no hay imagen disponible. Usa color por
/// categoria para que el catalogo siga siendo "visual" aunque no haya assets.
class _SignFallbackBadge extends StatelessWidget {
  final DgtSign sign;
  const _SignFallbackBadge({required this.sign});

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(sign.category);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          sign.code,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}

Color _colorForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'peligro':
      return const Color(0xFFFFC857);
    case 'prohibicion':
      return const Color(0xFFFF6B6B);
    case 'obligacion':
      return const Color(0xFF4F8AFF);
    case 'indicacion':
      return const Color(0xFF4FFFB0);
    default:
      return const Color(0xFFB9A6FF);
  }
}

class _SignDetailSheet extends ConsumerWidget {
  final DgtSign sign;
  const _SignDetailSheet({required this.sign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorForCategory(sign.category);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: _SignImage(sign: sign),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sign.code,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sign.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sign.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (sign.meaning.isNotEmpty)
              Text(
                sign.meaning,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: context.c.textSecondary,
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/study/widgets/dgt_tile.dart';
import 'package:memora/features/study/widgets/dgt_tile_spec.dart';
import 'package:memora/features/study/widgets/study_mode_tile.dart';

/// Issue #191 (dgt-tech): a11y baseline para tiles DGT.
/// Verifica que `Semantics` labels descriptivos se exponen para TalkBack /
/// VoiceOver, garantizando compliance WCAG AA basico.

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

DgtTileSpec _spec({
  String title = 'Simulacro DGT',
  String subtitle = '30 preguntas, 30 minutos',
  DgtTileVariant variant = DgtTileVariant.standard,
  DgtTileBadge? badge,
}) {
  return DgtTileSpec(
    title: title,
    subtitleBuilder: (_) => subtitle,
    icon: Icons.directions_car_rounded,
    accentColor: const Color(0xFFFF6B35),
    variant: variant,
    routeBuilder: (_) => const Scaffold(body: Text('destino')),
    badgeBuilder: badge == null ? null : (_) => badge,
  );
}

void main() {
  testWidgets(
    'DgtTile expone Semantics label con titulo + subtitulo + accion (standard)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(DgtTile(spec: _spec(title: 'Simulacro DGT'))),
      );
      // Label descriptivo formato "titulo. subtitulo. Pulsa para abrir".
      final found = find.bySemanticsLabel(
        RegExp(r'Simulacro DGT\..*Pulsa para abrir'),
      );
      expect(found, findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'DgtTile hero variant expone Semantics label (CTA simulacro)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(DgtTile(
          spec: _spec(
            title: 'Simulacro DGT',
            subtitle: 'CTA principal',
            variant: DgtTileVariant.hero,
          ),
        )),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Simulacro DGT\.')),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets(
    'DgtTile primary variant expone Semantics label (Estudio por Secciones)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(DgtTile(
          spec: _spec(
            title: 'Estudio por Secciones',
            subtitle: 'Clases teoricas',
            variant: DgtTileVariant.primary,
          ),
        )),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Estudio por Secciones\.')),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets(
    'DgtTile con badge expone el badge como Semantics value',
    (tester) async {
      const badge = DgtTileBadge(
        text: 'Recomendado',
        color: Color(0xFF4FA8FF),
      );
      await tester.pumpWidget(
        _wrap(DgtTile(
          spec: _spec(title: 'Estudio de hoy', badge: badge),
        )),
      );
      // Buscar Semantics con value="Recomendado".
      final semantics = tester.getSemantics(
        find.byType(DgtTile),
      );
      // El value puede estar anidado: verificar via traversal.
      var foundValue = false;
      void visit(SemanticsNode node) {
        if (node.value == 'Recomendado') foundValue = true;
        node.visitChildren((c) {
          visit(c);
          return true;
        });
      }
      visit(semantics);
      expect(foundValue, isTrue,
          reason: 'El badge debe exponerse como Semantics value');
    },
  );

  testWidgets(
    'StudyModeTile expone Semantics label + value cuando hay badge count',
    (tester) async {
      await tester.pumpWidget(
        _wrap(StudyModeTile(
          onTap: () {},
          accentColor: const Color(0xFFFF6B35),
          leadingIcon: Icons.star,
          title: 'Marcados',
          subtitle: 'Revisa tus favoritos',
          badgeCount: 5,
        )),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Marcados\..*Pulsa para abrir')),
        findsAtLeastNWidgets(1),
      );
      // Verificar value = "5 pendientes".
      final semantics = tester.getSemantics(find.byType(StudyModeTile));
      var foundValue = false;
      void visit(SemanticsNode node) {
        if (node.value == '5 pendientes') foundValue = true;
        node.visitChildren((c) {
          visit(c);
          return true;
        });
      }
      visit(semantics);
      expect(foundValue, isTrue);
    },
  );
}

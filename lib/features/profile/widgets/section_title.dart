import 'package:flutter/material.dart';

/// Pequeño título de sección con barra vertical dorada y texto en mayúsculas.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD24F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Color(0xFFFFD24F),
            ),
          ),
        ],
      ),
    );
  }
}

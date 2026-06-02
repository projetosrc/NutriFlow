// jantar_screen.dart
// Atalho para RefeicaoScreen com os dados do jantar.

import 'package:flutter/material.dart';
import 'refeicao_screen.dart';

class JantarScreen extends StatelessWidget {
  const JantarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RefeicaoScreen(
      nomeRefeicao: 'Jantar',
      timeRange:    '18:00 - 21:00',
      iconColor:    Color(0xFF7C83FD),
      iconBgColor:  Color(0xFFEEF0FF),
      icon:         Icons.nightlight_round,
    );
  }
}

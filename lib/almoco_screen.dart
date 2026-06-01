// almoco_screen.dart
// Atalho para RefeicaoScreen com os dados do almoço.

import 'package:flutter/material.dart';
import 'refeicao_screen.dart';

class AlmocoScreen extends StatelessWidget {
  const AlmocoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RefeicaoScreen(
      nomeRefeicao: 'Almoço',
      timeRange:    '12:00 - 14:00',
      iconColor:    Color(0xFFFFB703),
      iconBgColor:  Color(0xFFFFF8E1),
      icon:         Icons.wb_sunny,
    );
  }
}

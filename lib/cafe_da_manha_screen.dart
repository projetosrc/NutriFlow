// cafe_da_manha_screen.dart
// Agora é só um atalho para RefeicaoScreen com os dados do café da manhã.
// O código real está em refeicao_screen.dart.

import 'package:flutter/material.dart';
import 'refeicao_screen.dart';

class CafeDaManhaScreen extends StatelessWidget {
  const CafeDaManhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RefeicaoScreen(
      nomeRefeicao: 'Café da Manhã',
      timeRange:    '06:00 - 09:00',
      iconColor:    Color(0xFFF4A261),
      iconBgColor:  Color(0xFFFFF0E0),
      icon:         Icons.wb_twilight,
    );
  }
}

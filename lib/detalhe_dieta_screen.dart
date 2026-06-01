// =============================================================
//  detalhe_dieta_screen.dart
//  Tela de detalhes de uma dieta favorita — NutriFlow
//
//  Exibe os alimentos de cada refeição (Café da Manhã, Almoço
//  e Jantar) que foram salvos junto com a dieta favoritada.
// =============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _kTeal = Colors.teal;

class DetalheDietaScreen extends StatelessWidget {
  final String nome;
  final Map<String, dynamic> data;

  const DetalheDietaScreen({
    super.key,
    required this.nome,
    required this.data,
  });

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _formatData(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final totalCal  = (data['totalCalorias'] ?? 0).toDouble();
    final totalCarb = (data['totalCarb']     ?? 0).toDouble();
    final totalProt = (data['totalProt']     ?? 0).toDouble();
    final totalGord = (data['totalGord']     ?? 0).toDouble();
    final totalFib  = (data['totalFib']      ?? 0).toDouble();
    final criadaEm  = data['criadaEm'] as Timestamp?;

    // itens: Map<nomeRefeicao, List<Map>>
    final itens = data['itens'] as Map<String, dynamic>? ?? {};

    final refeicoes = [
      _RefeicaoInfo(
        nome: 'Café da Manhã',
        icone: Icons.wb_twilight,
        corIcone: const Color(0xFFF4A261),
        corFundo: const Color(0xFFFFF0E0),
        corChip: const Color(0xFFF4A261),
        horario: '06:00 - 09:00',
      ),
      _RefeicaoInfo(
        nome: 'Almoço',
        icone: Icons.wb_sunny,
        corIcone: const Color(0xFFFFB703),
        corFundo: const Color(0xFFFFF8E1),
        corChip: const Color(0xFFFFB703),
        horario: '12:00 - 14:00',
      ),
      _RefeicaoInfo(
        nome: 'Jantar',
        icone: Icons.nightlight_round,
        corIcone: const Color(0xFF7C83FD),
        corFundo: const Color(0xFFEEF0FF),
        corChip: const Color(0xFF7C83FD),
        horario: '18:00 - 21:00',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      // ── APP BAR ─────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
        ),
        title: Text(
          nome,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),

      // ── CORPO ────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card resumo total do dia ───────────────────────
            _buildResumoCard(
              criadaEm: criadaEm,
              totalCal: totalCal,
              totalCarb: totalCarb,
              totalProt: totalProt,
              totalGord: totalGord,
              totalFib: totalFib,
            ),

            const SizedBox(height: 24),

            const Text(
              'Refeições',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 12),

            // ── Cards de cada refeição ─────────────────────────
            ...refeicoes.map((ref) {
              final lista = itens[ref.nome] as List<dynamic>? ?? [];
              return _buildRefeicaoCard(ref, lista);
            }).toList(),

            const SizedBox(height: 24),
          ],
        ),
      ),

      // ── BOTTOM NAV ──────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: _kTeal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu), label: 'Dieta'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        },
      ),
    );
  }

  // ── Card de resumo nutricional do dia ──────────────────────
  Widget _buildResumoCard({
    required Timestamp? criadaEm,
    required double totalCal,
    required double totalCarb,
    required double totalProt,
    required double totalGord,
    required double totalFib,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total do dia',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    if (criadaEm != null)
                      Text(
                        'Salva em ${_formatData(criadaEm)}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _totalItem('${_fmt(totalCal)} kcal', 'Calorias', _kTeal),
                  _totalItem('${_fmt(totalCarb)}g', 'Carb', Colors.orange),
                  _totalItem('${_fmt(totalProt)}g', 'Prot', Colors.blue),
                  _totalItem('${_fmt(totalGord)}g', 'Gord', Colors.purple),
                  _totalItem('${_fmt(totalFib)}g', 'Fib', Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card de uma refeição com seus alimentos ─────────────────
  Widget _buildRefeicaoCard(
      _RefeicaoInfo ref, List<dynamic> alimentos) {
    // soma local dos macros desta refeição
    double cal = 0, carb = 0, prot = 0, gord = 0;
    for (final item in alimentos) {
      final m = item as Map<String, dynamic>;
      cal  += (m['calorias'] ?? 0).toDouble();
      carb += (m['carb']     ?? 0).toDouble();
      prot += (m['prot']     ?? 0).toDouble();
      gord += (m['gord']     ?? 0).toDouble();
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho da refeição ──────────────────────
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ref.corFundo,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(ref.icone, color: ref.corIcone, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref.nome,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      Text(ref.horario,
                          style: const TextStyle(
                              fontSize: 12,
                              color: _kTeal,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                // Total de kcal da refeição
                Text(
                  '${_fmt(cal)} kcal',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: ref.corIcone),
                ),
              ],
            ),

            // ── Macros resumo da refeição ──────────────────
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: ref.corFundo.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroChip('Carb', '${_fmt(carb)}g', ref.corChip),
                  _macroChip('Prot', '${_fmt(prot)}g', ref.corChip),
                  _macroChip('Gord', '${_fmt(gord)}g', ref.corChip),
                ],
              ),
            ),

            // ── Lista de alimentos ─────────────────────────
            if (alimentos.isEmpty) ...[
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Nenhum alimento nesta refeição',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...alimentos.map((item) {
                final m = item as Map<String, dynamic>;
                return _buildAlimentoItem(m, ref.corChip);
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Item de alimento dentro do card ─────────────────────────
  Widget _buildAlimentoItem(Map<String, dynamic> item, Color cor) {
    final nome    = item['nome']     as String? ?? '';
    final porcao  = item['porcao']   as String? ?? '';
    final cal     = (item['calorias'] ?? 0).toDouble();
    final carb    = (item['carb']     ?? 0).toDouble();
    final prot    = (item['prot']     ?? 0).toDouble();
    final gord    = (item['gord']     ?? 0).toDouble();
    final fib     = (item['fib']      ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ponto colorido
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome + kcal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nome,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                    ),
                    Text(
                      '${_fmt(cal)} kcal',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cor),
                    ),
                  ],
                ),
                // Porção
                if (porcao.isNotEmpty)
                  Text(porcao,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                // Macros inline
                Wrap(
                  spacing: 10,
                  children: [
                    _inlineMacro('Carb', '${_fmt(carb)}g'),
                    _inlineMacro('Prot', '${_fmt(prot)}g'),
                    _inlineMacro('Gord', '${_fmt(gord)}g'),
                    _inlineMacro('Fib',  '${_fmt(fib)}g'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalItem(String valor, String label, Color cor) {
    return Column(
      children: [
        Text(valor,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: cor)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _macroChip(String label, String valor, Color cor) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: cor, fontWeight: FontWeight.w500)),
        Text(valor,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ],
    );
  }

  Widget _inlineMacro(String label, String valor) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.grey)),
          TextSpan(
              text: valor,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Modelo auxiliar de refeição ──────────────────────────────
class _RefeicaoInfo {
  final String nome;
  final IconData icone;
  final Color corIcone;
  final Color corFundo;
  final Color corChip;
  final String horario;

  const _RefeicaoInfo({
    required this.nome,
    required this.icone,
    required this.corIcone,
    required this.corFundo,
    required this.corChip,
    required this.horario,
  });
}

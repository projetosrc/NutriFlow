// refeicao_screen.dart
// Tela de detalhes de uma refeição — NutriFlow
//
// Esse arquivo substituiu os três arquivos separados
// (cafe_da_manha_screen, almoco_screen, jantar_screen) que eram
// praticamente idênticos. Agora é só parametrizar e pronto.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'adicionar_alimento_screen.dart';
import 'editar_gramas_sheet.dart';
import 'perfil_page.dart';

class RefeicaoScreen extends StatelessWidget {
  final String   nomeRefeicao;
  final String   timeRange;
  final Color    iconColor;
  final Color    iconBgColor;
  final IconData icon;

  const RefeicaoScreen({
    super.key,
    required this.nomeRefeicao,
    required this.timeRange,
    required this.iconColor,
    required this.iconBgColor,
    required this.icon,
  });

  // monta o ID do doc: uid_NomeRefeicao (espaços viram _)
  String get _docId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return '${uid}_${nomeRefeicao.replaceAll(' ', '_')}';
  }

  @override
  Widget build(BuildContext context) {
    // referência à subcoleção de itens, ordenada por data de adição
    final itensRef = FirebaseFirestore.instance
        .collection('refeicoes_usuario')
        .doc(_docId)
        .collection('itens')
        .orderBy('adicionadoEm', descending: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
        ),
        title: Text(nomeRefeicao,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          // botão "+" para adicionar alimento
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AdicionarAlimentoScreen(nomeRefeicao: nomeRefeicao),
              )),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: Colors.teal, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),

      // StreamBuilder escuta a subcoleção de itens e recalcula tudo
      body: StreamBuilder<QuerySnapshot>(
        stream: itensRef.snapshots(),
        builder: (context, snapshot) {
          // mostra loading enquanto carrega pela primeira vez
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmptyState(context);

          // calcula os totais somando todos os itens
          double totalCal = 0, totalCarb = 0, totalProt = 0, totalGord = 0;
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            totalCal  += (d['calorias'] ?? 0).toDouble();
            totalCarb += (d['carb']     ?? 0).toDouble();
            totalProt += (d['prot']     ?? 0).toDouble();
            totalGord += (d['gord']     ?? 0).toDouble();
          }

          return Column(
            children: [
              // card de resumo no topo
              _buildResumoCard(docs.length, totalCal, totalCarb, totalProt, totalGord),

              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Alimentos adicionados',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text('Toque para editar',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),

              // lista de alimentos com swipe para remover e toque para editar
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _buildItemCard(
                    context,
                    docs[i].data() as Map<String, dynamic>,
                    docs[i].reference,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildResumoCard(int qtd, double cal, double carb, double prot, double gord) {
    String fmt(double v) => v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // cabeçalho com ícone + nome + quantidade de itens
              Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                        color: iconBgColor, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nomeRefeicao,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                      Text(timeRange,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.teal, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  Text('$qtd item${qtd != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 14),

              // totais de macros com fundo colorido
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                    color: iconBgColor, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    _totalItem('Calorias', '${fmt(cal)} kcal'),
                    _totalItem('Carb',     '${fmt(carb)}g'),
                    _totalItem('Prot',     '${fmt(prot)}g'),
                    _totalItem('Gord',     '${fmt(gord)}g'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: iconBgColor, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: iconColor, size: 40),
          ),
          const SizedBox(height: 20),
          Text(nomeRefeicao,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Nenhum alimento adicionado ainda.',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          const Text('Toque em + para adicionar.',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AdicionarAlimentoScreen(nomeRefeicao: nomeRefeicao),
            )),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon:  const Icon(Icons.add, color: Colors.white),
            label: const Text('Adicionar alimento',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> d, DocumentReference docRef) {
    String fmt(double v) => v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);

    final cal  = (d['calorias'] ?? 0).toDouble();
    final carb = (d['carb']     ?? 0).toDouble();
    final prot = (d['prot']     ?? 0).toDouble();
    final gord = (d['gord']     ?? 0).toDouble();
    final fib  = (d['fib']      ?? 0).toDouble();

    return Dismissible(
      key: Key(docRef.id),
      direction: DismissDirection.endToStart,
      // fundo vermelho aparece ao deslizar para a esquerda
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.red.shade100, borderRadius: BorderRadius.circular(14)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 26),
            SizedBox(height: 4),
            Text('Remover',
                style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      // pede confirmação antes de deletar
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Remover alimento'),
          content: Text('Remover "${d['nome']}" de $nomeRefeicao?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        // deleta o item e atualiza os totais do doc pai
        await docRef.delete();
        await FirebaseFirestore.instance
            .collection('refeicoes_usuario')
            .doc(_docId)
            .update({
          'totalCalorias': FieldValue.increment(-cal),
          'totalCarb':     FieldValue.increment(-carb),
          'totalProt':     FieldValue.increment(-prot),
          'totalGord':     FieldValue.increment(-gord),
          'totalFib':      FieldValue.increment(-fib),
        });
      },
      child: GestureDetector(
        // abre o sheet de editar gramas ao tocar no card
        onTap: () => EditarGramasSheet.show(
          context:       context,
          itemData:      d,
          docRef:        docRef,
          refeicaoDocId: _docId,
          iconColor:     iconColor,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: iconBgColor, borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // nome do alimento + calorias na mesma linha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(d['nome'] ?? '',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('${fmt(cal)} kcal',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: iconColor)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(d['porcao'] ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 10),

                // macros em linha
                Row(
                  children: [
                    _macroChip('Carb', '${fmt(carb)}g'),
                    _macroChip('Prot', '${fmt(prot)}g'),
                    _macroChip('Gord', '${fmt(gord)}g'),
                    _macroChip('Fib',  '${fmt(fib)}g'),
                  ],
                ),
                const SizedBox(height: 6),

                // dicas de interação
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.touch_app_outlined, size: 13, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Toque para editar gramas',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                    Row(children: [
                      Icon(Icons.swipe_left, size: 13, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Deslize para remover',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalItem(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    ),
  );

  Widget _macroChip(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, color: iconColor, fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    ),
  );

  Widget _buildBottomNav(BuildContext context) => BottomNavigationBar(
    currentIndex: 0,
    selectedItemColor:   Colors.teal,
    unselectedItemColor: Colors.grey,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Dieta'),
      BottomNavigationBarItem(icon: Icon(Icons.person),           label: 'Perfil'),
    ],
    onTap: (index) {
      if (index == 0) {
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PerfilPage()));
      }
    },
  );
}

// =============================================================
//  minha_dieta_screen.dart
//  Tela "Minhas Dietas" do app NutriFlow
//
//  MUDANÇA:
//  - Lista em tempo real as dietas salvas na coleção
//    'dietas_favoritas' do Firestore para o usuário logado.
//  - Cada card exibe: nome, data de criação e macros (cal,
//    carb, prot, gord).
//  - Deslize para a esquerda para excluir uma dieta.
//  - FAB "+" reservado para criação manual futura.
// =============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'detalhe_dieta_screen.dart';

const Color kTealDieta = Colors.teal;

class MinhaDietaScreen extends StatelessWidget {
  const MinhaDietaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      // ── APP BAR ───────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
        ),
        title: const Text(
          'Minhas Dietas',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),

      // ── CORPO ─────────────────────────────────────────────
      body: uid == null
          ? const Center(child: Text('Usuário não autenticado.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('dietas_favoritas')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                // Carregando…
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: kTealDieta),
                  );
                }

                // Erro
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro: ${snapshot.error}'),
                  );
                }

                // Ordena localmente por criadaEm (mais recente primeiro)
                final docs = (snapshot.data?.docs ?? [])
                  ..sort((a, b) {
                    final aTs = (a.data() as Map<String, dynamic>)['criadaEm'];
                    final bTs = (b.data() as Map<String, dynamic>)['criadaEm'];
                    if (aTs == null || bTs == null) return 0;
                    return (bTs as dynamic).compareTo(aTs);
                  });

                // Estado vazio
                if (docs.isEmpty) {
                  return const _EmptyState();
                }

                // Lista de dietas
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _DietaCard(
                      docId: doc.id,
                      data: data,
                    );
                  },
                );
              },
            ),

      // ── FAB ───────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: criação manual de dieta
        },
        backgroundColor: kTealDieta,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,

      // ── BOTTOM NAV ────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: kTealDieta,
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
}

// =============================================================
//  Card de cada dieta favorita
// =============================================================
class _DietaCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _DietaCard({required this.docId, required this.data});

  String _fmt(double v) => v == v.truncateToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1);

  String _formatData(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  Future<void> _confirmarExcluir(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir dieta'),
        content: Text('Deseja excluir "${data['nome']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseFirestore.instance
          .collection('dietas_favoritas')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome      = data['nome']          as String? ?? 'Sem nome';
    final totalCal  = (data['totalCalorias'] ?? 0).toDouble();
    final totalCarb = (data['totalCarb']     ?? 0).toDouble();
    final totalProt = (data['totalProt']     ?? 0).toDouble();
    final totalGord = (data['totalGord']     ?? 0).toDouble();
    final totalFib  = (data['totalFib']      ?? 0).toDouble();
    final criadaEm  = data['criadaEm'] as Timestamp?;

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_outline, color: Colors.red, size: 26),
            SizedBox(height: 4),
            Text('Excluir',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Excluir dieta'),
            content: Text('Deseja excluir "$nome"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return confirmar ?? false;
      },
      onDismissed: (_) async {
        await FirebaseFirestore.instance
            .collection('dietas_favoritas')
            .doc(docId)
            .delete();
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalheDietaScreen(
              nome: nome,
              data: data,
            ),
          ),
        ),
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Linha 1: ícone + nome + data ──────────────
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: const TextStyle(
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
                  ),
                  // Botão excluir (alternativa ao deslize)
                  IconButton(
                    onPressed: () => _confirmarExcluir(context),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.grey, size: 20),
                    tooltip: 'Excluir dieta',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Linha 2: macros ───────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _macroItem(
                        '${_fmt(totalCal)} kcal', 'Calorias',
                        kTealDieta),
                    _macroItem('${_fmt(totalCarb)}g', 'Carb',
                        Colors.orange),
                    _macroItem('${_fmt(totalProt)}g', 'Prot',
                        Colors.blue),
                    _macroItem('${_fmt(totalGord)}g', 'Gord',
                        Colors.purple),
                    _macroItem('${_fmt(totalFib)}g', 'Fib',
                        Colors.green),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Dica deslize ──────────────────────────────
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.swipe_left, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Deslize para excluir',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        ), // fecha Card
      ), // fecha GestureDetector
    );
  }

  Widget _macroItem(String valor, String label, Color cor) {
    return Column(
      children: [
        Text(valor,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cor)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// =============================================================
//  Estado vazio
// =============================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border_rounded,
              size: 72, color: Color(0xFFCCCCCC)),
          SizedBox(height: 16),
          Text(
            'Nenhuma dieta salva ainda',
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Abra "Refeições" e toque em ⭐ para salvar',
            style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

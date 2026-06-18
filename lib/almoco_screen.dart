// =============================================================
//  almoco_screen.dart
//  Tela de Almoço — NutriFlow
//
//  MUDANÇA: toque no card do alimento abre o EditarGramasSheet.
// =============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'adicionar_alimento_screen.dart';
import 'editar_gramas_sheet.dart';
import 'perfil_page.dart';

class AlmocoScreen extends StatelessWidget {
  const AlmocoScreen({super.key});

  static const String _nomeRefeicao = 'Almoço';
  static const String _timeRange    = '12:00 - 14:00';
  static const Color  _iconColor    = Color(0xFFFFB703);
  static const Color  _iconBgColor  = Color(0xFFFFF8E1);
  static const Color  _kTeal        = Colors.teal;

  @override
  Widget build(BuildContext context) {
    final uid   = FirebaseAuth.instance.currentUser?.uid;
    final docId = '${uid}_Almoço';

    final itensRef = FirebaseFirestore.instance
        .collection('refeicoes_usuario')
        .doc(docId)
        .collection('itens')
        .orderBy('adicionadoEm', descending: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
        ),
        title: const Text(
          _nomeRefeicao,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdicionarAlimentoScreen(
                      nomeRefeicao: _nomeRefeicao),
                ),
              ),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kTeal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: itensRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kTeal));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) return _buildEmptyState(context);

          double totalCal  = 0;
          double totalCarb = 0;
          double totalProt = 0;
          double totalGord = 0;
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            totalCal  += (d['calorias'] ?? 0).toDouble();
            totalCarb += (d['carb']     ?? 0).toDouble();
            totalProt += (d['prot']     ?? 0).toDouble();
            totalGord += (d['gord']     ?? 0).toDouble();
          }

          return Column(
            children: [
              _buildResumoCard(
                  docs.length, totalCal, totalCarb, totalProt, totalGord),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Alimentos adicionados',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    Text('Toque para editar',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _buildItemCard(
                      context,
                      docs[i].data() as Map<String, dynamic>,
                      docs[i].reference,
                      docId),
                ),
              ),
            ],
          );
        },
      ),

      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildResumoCard(
      int qtd, double cal, double carb, double prot, double gord) {
    String fmt(double v) => v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _iconBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.wb_sunny,
                        color: _iconColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Almoço',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      Text(_timeRange,
                          style: TextStyle(
                              fontSize: 13,
                              color: _kTeal,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  Text('$qtd item${qtd != 1 ? 's' : ''}',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _totalItem('Calorias', '${fmt(cal)} kcal'),
                    _totalItem('Carb', '${fmt(carb)}g'),
                    _totalItem('Prot', '${fmt(prot)}g'),
                    _totalItem('Gord', '${fmt(gord)}g'),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _iconBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.wb_sunny, color: _iconColor, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Almoço',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Nenhum alimento adicionado ainda.',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          const Text('Toque em + para adicionar.',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdicionarAlimentoScreen(
                    nomeRefeicao: _nomeRefeicao),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Adicionar alimento',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> d,
      DocumentReference docRef, String refeicaoDocId) {
    String fmt(double v) => v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);

    final double cal  = (d['calorias'] ?? 0).toDouble();
    final double carb = (d['carb']     ?? 0).toDouble();
    final double prot = (d['prot']     ?? 0).toDouble();
    final double gord = (d['gord']     ?? 0).toDouble();
    final double fib  = (d['fib']      ?? 0).toDouble();

    return Dismissible(
      key: Key(docRef.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_outline, color: Colors.red, size: 26),
            SizedBox(height: 4),
            Text('Remover',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Remover alimento'),
          content: Text('Remover "${d['nome']}" do Almoço?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.grey))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remover',
                    style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
      onDismissed: (_) async {
        // Lê os itens ANTES de remover e recalcula os totais ignorando o
        // item que está sendo excluído (evita valores negativos/drift).
        final itensSnap = await FirebaseFirestore.instance
            .collection('refeicoes_usuario')
            .doc(refeicaoDocId)
            .collection('itens')
            .get();
        double newCal = 0, newCarb = 0, newProt = 0, newGord = 0, newFib = 0;
        for (final item in itensSnap.docs) {
          if (item.id == docRef.id) continue; // ignora o item removido
          final d = item.data();
          newCal  += (d['calorias'] ?? 0).toDouble();
          newCarb += (d['carb']     ?? 0).toDouble();
          newProt += (d['prot']     ?? 0).toDouble();
          newGord += (d['gord']     ?? 0).toDouble();
          newFib  += (d['fib']      ?? 0).toDouble();
        }
        // Remoção do item + atualização dos totais de forma atômica (DEF-008).
        final batch = FirebaseFirestore.instance.batch();
        batch.delete(docRef);
        batch.update(
          FirebaseFirestore.instance
              .collection('refeicoes_usuario')
              .doc(refeicaoDocId),
          {
            'totalCalorias': newCal,
            'totalCarb':     newCarb,
            'totalProt':     newProt,
            'totalGord':     newGord,
            'totalFib':      newFib,
          },
        );
        await batch.commit();
      },
      child: GestureDetector(
        onTap: () => EditarGramasSheet.show(
          context: context,
          itemData: d,
          docRef: docRef,
          refeicaoDocId: refeicaoDocId,
          iconColor: _iconColor,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        const Icon(Icons.edit_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('${fmt(cal)} kcal',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _iconColor)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(d['porcao'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _macroChip('Carb', '${fmt(carb)}g', _iconColor),
                    _macroChip('Prot', '${fmt(prot)}g', _iconColor),
                    _macroChip('Gord', '${fmt(gord)}g', _iconColor),
                    _macroChip('Fib',  '${fmt(fib)}g',  _iconColor),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.touch_app_outlined,
                            size: 13, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Toque para editar gramas',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.swipe_left,
                            size: 13, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Deslize para remover',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
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
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ],
        ),
      );

  Widget _macroChip(String label, String value, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ],
        ),
      );

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
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
        } else if (index == 1) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PerfilPage()));
        }
      },
    );
  }
}

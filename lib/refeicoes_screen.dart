// refeicoes_screen.dart
// Exibe os 3 cards de refeição (Café da Manhã, Almoço, Jantar)
// com botão de confirmar/desconfirmar cada uma.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'refeicao_screen.dart';
import 'perfil_page.dart';

// modelo de dados de cada refeição — facilita criar os cards num loop
class MealData {
  final String name;
  final String firestoreName;
  final String timeRange;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const MealData({
    required this.name,
    required this.firestoreName,
    required this.timeRange,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });
}

// lista das 3 refeições — se precisar adicionar lanche basta colocar aqui
const _meals = [
  MealData(
    name:          'Café da Manhã',
    firestoreName: 'Café_da_Manhã',
    timeRange:     '06:00 - 09:00',
    icon:          Icons.wb_twilight,
    iconColor:     Color(0xFFF4A261),
    iconBgColor:   Color(0xFFFFF0E0),
  ),
  MealData(
    name:          'Almoço',
    firestoreName: 'Almoço',
    timeRange:     '12:00 - 14:00',
    icon:          Icons.wb_sunny,
    iconColor:     Color(0xFFFFB703),
    iconBgColor:   Color(0xFFFFF8E1),
  ),
  MealData(
    name:          'Jantar',
    firestoreName: 'Jantar',
    timeRange:     '18:00 - 21:00',
    icon:          Icons.nightlight_round,
    iconColor:     Color(0xFF7C83FD),
    iconBgColor:   Color(0xFFEEF0FF),
  ),
];

// RefeicoeBody: só o corpo sem Scaffold — embutido direto na HomePage
class RefeicoeBody extends StatefulWidget {
  const RefeicoeBody({super.key});

  @override
  State<RefeicoeBody> createState() => _RefeicoeBodyState();
}

class _RefeicoeBodyState extends State<RefeicoeBody> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // ─── CONFIRMAR / DESCONFIRMAR ─────────────────────────────────
  //
  // Confirmar: salva snapshot (cal+prot no momento do clique) no doc
  //   da refeição e incrementa o consumo do usuário.
  //
  // Desconfirmar: lê o snapshot salvo para subtrair EXATAMENTE o que
  //   foi somado antes — não importa se o usuário editou depois.
  // Obs: *Futura Implementação*.
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmarRefeicao({
    required String mealFirestoreName,
    required double totalCal,
    required double totalProt,
    required bool jaConfirmada,
  }) async {
    if (_uid == null) return;

    final userDoc = FirebaseFirestore.instance.collection('usuarios').doc(_uid);
    final refeicaoDoc = FirebaseFirestore.instance
        .collection('refeicoes_usuario')
        .doc('${_uid}_$mealFirestoreName');

    if (jaConfirmada) {
      // ── desfaz a confirmação ─────────────────────────────────
      final snap = await refeicaoDoc.get();

      // usa os valores do snapshot para subtrair exatamente o que foi somado
      double calSubtrair  = totalCal;
      double protSubtrair = totalProt;
    

      if (snap.exists) {
        final d = snap.data()!;
        calSubtrair  = (d['calConfirmada']  ?? totalCal).toDouble();
        protSubtrair = (d['protConfirmada'] ?? totalProt).toDouble();
      }

      // garante que o consumido não fique negativo
      final userSnap = await userDoc.get();
      if (userSnap.exists) {
        final consumidoAtual = (userSnap.data()!['consumidoCalorias'] ?? 0).toDouble();
        if (calSubtrair > consumidoAtual) calSubtrair = consumidoAtual;
      }

      await userDoc.set({
        'consumidoCalorias': FieldValue.increment(-calSubtrair),
        'consumidoProteina': FieldValue.increment(-protSubtrair),
      }, SetOptions(merge: true));

      await refeicaoDoc.set({
        'confirmada':     false,
        'calConfirmada':  0,
        'protConfirmada': 0,
      }, SetOptions(merge: true));

      if (mounted) {
        _showSnack('Refeição desmarcada. -${calSubtrair.toInt()} kcal removidas.');
      }
    } else {
      // ── confirma e soma as calorias ──────────────────────────
      await refeicaoDoc.set({
        'confirmada':     true,
        'calConfirmada':  totalCal,
        'protConfirmada': totalProt,
      }, SetOptions(merge: true));

      await userDoc.set({
        'consumidoCalorias': FieldValue.increment(totalCal),
        'consumidoProteina': FieldValue.increment(totalProt),
      }, SetOptions(merge: true));

      if (mounted) {
        _showSnack('Refeição confirmada! +${totalCal.toInt()} kcal',
            color: Colors.teal);
      }
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Suas Refeições',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            'Adicione e organize suas refeições diarias',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // gera um card para cada refeição da lista
          for (final meal in _meals) _buildMealCard(meal),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMealCard(MealData meal) {
    final docId = '${_uid}_${meal.firestoreName}';

    // StreamBuilder no doc pai: lê o flag 'confirmada' em tempo real
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refeicoes_usuario')
          .doc(docId)
          .snapshots(),
      builder: (context, snapDoc) {
        final confirmada = snapDoc.hasData &&
            snapDoc.data!.exists &&
            (snapDoc.data!.data() as Map)['confirmada'] == true;

        // StreamBuilder na subcoleção de itens: recalcula os totais em tempo real
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('refeicoes_usuario')
              .doc(docId)
              .collection('itens')
              .snapshots(),
          builder: (context, snapItens) {
            double totalCal = 0, totalCarb = 0, totalProt = 0, totalGord = 0;

            if (snapItens.hasData) {
              for (final doc in snapItens.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                totalCal  += (d['calorias'] ?? 0).toDouble();
                totalCarb += (d['carb']     ?? 0).toDouble();
                totalProt += (d['prot']     ?? 0).toDouble();
                totalGord += (d['gord']     ?? 0).toDouble();
              }
            }

            // formata sem casas decimais desnecessárias (ex: 100 em vez de 100.0)
            String fmt(double v) => v == v.truncateToDouble()
                ? v.toInt().toString()
                : v.toStringAsFixed(1);

            return GestureDetector(
              // toca no card — abre a tela de detalhes da refeição
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RefeicaoScreen(
                    nomeRefeicao: meal.name,
                    timeRange:    meal.timeRange,
                    iconColor:    meal.iconColor,
                    iconBgColor:  meal.iconBgColor,
                    icon:         meal.icon,
                  ),
                ),
              ),
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  // borda teal quando confirmada
                  side: confirmada
                      ? const BorderSide(color: Colors.teal, width: 1.5)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [

                      // linha com ícone + nome da refeição + horário
                      Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: meal.iconBgColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(meal.icon, color: meal.iconColor, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(meal.name,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87)),
                                const SizedBox(height: 2),
                                Text(meal.timeRange,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.teal,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // linha com os macros calculados em tempo real
                      Row(
                        children: [
                          _macroItem('Carb:',     '${fmt(totalCarb)}g'),
                          _macroItem('Prot:',     '${fmt(totalProt)}g'),
                          _macroItem('Gord:',     '${fmt(totalGord)}g'),
                          _macroItem('Calorias:', '${fmt(totalCal)} kcal'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // botão de confirmar — muda visual quando já confirmada
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmarRefeicao(
                            mealFirestoreName: meal.firestoreName,
                            totalCal:          totalCal,
                            totalProt:         totalProt,
                            jaConfirmada:      confirmada,
                          ),
                          icon: Icon(
                            confirmada
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            size: 18,
                            color: confirmada ? Colors.white : Colors.teal,
                          ),
                          label: Text(
                            confirmada ? 'Refeição confirmada' : 'Confirmar refeição',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: confirmada ? Colors.white : Colors.teal,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmada
                                ? Colors.teal
                                : Colors.teal.shade50,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _macroItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}

// RefeicoeScreen: versão com Scaffold — mantida caso alguma tela
// ainda navegue diretamente pra cá
class RefeicoeScreen extends StatelessWidget {
  const RefeicoeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
       
        title: const Text(
          'Refeições',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: const RefeicoeBody(),
      bottomNavigationBar: BottomNavigationBar(
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
      ),
    );
  }
}

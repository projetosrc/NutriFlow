// =============================================================
//  refeicoes_screen.dart — NutriFlow
//
//  NOVO: botao "Confirmar refeicao" em cada card.
//  Ao tocar, marca a refeicao como consumida e soma
//  calorias + proteina no documento do usuario no Firestore
//  (campos: consumidoCalorias, consumidoProteina).
//  A tela de Perfil le esses campos em tempo real.
// =============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cafe_da_manha_screen.dart';
import 'almoco_screen.dart';
import 'jantar_screen.dart';
import 'perfil_page.dart';

const Color kTeal = Colors.teal;

class RefeicoeScreen extends StatefulWidget {
  const RefeicoeScreen({super.key});

  @override
  State<RefeicoeScreen> createState() => _RefeicoeScreenState();
}

class _RefeicoeScreenState extends State<RefeicoeScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  final List<MealData> meals = [
    MealData(
      name: 'Cafe da Manha',
      firestoreName: 'Café_da_Manhã',
      timeRange: '06:00 - 09:00',
      icon: Icons.wb_twilight,
      iconColor: Color(0xFFF4A261),
      iconBgColor: Color(0xFFFFF0E0),
      iconType: 'twilight',
      destinationBuilder: (_) => const CafeDaManhaScreen(),
    ),
    MealData(
      name: 'Almoco',
      firestoreName: 'Almoço',
      timeRange: '12:00 - 14:00',
      icon: Icons.wb_sunny,
      iconColor: Color(0xFFFFB703),
      iconBgColor: Color(0xFFFFF8E1),
      iconType: 'sun',
      destinationBuilder: (_) => const AlmocoScreen(),
    ),
    MealData(
      name: 'Jantar',
      firestoreName: 'Jantar',
      timeRange: '18:00 - 21:00',
      icon: Icons.nightlight_round,
      iconColor: Color(0xFF7C83FD),
      iconBgColor: Color(0xFFEEF0FF),
      iconType: 'moon',
      destinationBuilder: (_) => const JantarScreen(),
    ),
  ];

  // ─────────────────────────────────────────────────────────────
  //  Confirma refeicao: soma cal+prot no doc do usuario
  // ─────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────
  //  CONFIRMAR / DESCONFIRMAR REFEIÇÃO
  //
  //  AO CONFIRMAR:
  //   - Soma cal+prot no doc do usuário (consumidoCalorias / consumidoProteina)
  //   - Salva um snapshot (calConfirmada, protConfirmada) no doc da refeição
  //     para poder subtrair EXATAMENTE o mesmo valor ao desconfirmar.
  //
  //  AO DESCONFIRMAR:
  //   - Lê calConfirmada / protConfirmada do doc da refeição (snapshot salvo)
  //   - Subtrai esse valor exato do doc do usuário → valores voltam ao estado
  //     que tinham antes da confirmação, independente de alimentos adicionados depois.
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmarRefeicao({
    required String mealFirestoreName,
    required double totalCal,
    required double totalProt,
    required bool jaConfirmada,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final userDoc = FirebaseFirestore.instance.collection('usuarios').doc(uid);
    final refeicaoDoc = FirebaseFirestore.instance
        .collection('refeicoes_usuario')
        .doc('${uid}_$mealFirestoreName');

    if (jaConfirmada) {
      // ── DESCONFIRMAR ────────────────────────────────────────
      // Lê o snapshot salvo no momento da confirmação
      final snap = await refeicaoDoc.get();
      double calParaSubtrair  = totalCal;
      double protParaSubtrair = totalProt;

      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>;
        // Usa o snapshot gravado; se não existir, usa o valor atual (fallback)
        calParaSubtrair  = (d['calConfirmada']  ?? totalCal).toDouble();
        protParaSubtrair = (d['protConfirmada'] ?? totalProt).toDouble();
      }

      // Garante que consumido não fique negativo
      final userSnap = await userDoc.get();
      if (userSnap.exists) {
        final ud = userSnap.data() as Map<String, dynamic>;
        final consumidoAtual = (ud['consumidoCalorias'] ?? 0).toDouble();
        if (calParaSubtrair > consumidoAtual) {
          calParaSubtrair = consumidoAtual;
        }
      }

      await userDoc.set({
        'consumidoCalorias': FieldValue.increment(-calParaSubtrair),
        'consumidoProteina': FieldValue.increment(-protParaSubtrair),
      }, SetOptions(merge: true));

      await refeicaoDoc.set({
        'confirmada':      false,
        'calConfirmada':   0,
        'protConfirmada':  0,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refeição desmarcada. -${calParaSubtrair.toInt()} kcal removidas.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      // ── CONFIRMAR ───────────────────────────────────────────
      // Salva snapshot dos valores confirmados para poder desfazer exatamente
      await refeicaoDoc.set({
        'confirmada':     true,
        'calConfirmada':  totalCal,   // snapshot — valor exato somado
        'protConfirmada': totalProt,  // snapshot — valor exato somado
      }, SetOptions(merge: true));

      await userDoc.set({
        'consumidoCalorias': FieldValue.increment(totalCal),
        'consumidoProteina': FieldValue.increment(totalProt),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refeição confirmada! +${totalCal.toInt()} kcal'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Coleta os totais do dia e abre o pop-up para salvar dieta
  // ─────────────────────────────────────────────────────────────
  Future<void> _abrirDialogFavoritar() async {
    final uid = _uid;
    if (uid == null) return;

    double totalCal  = 0;
    double totalCarb = 0;
    double totalProt = 0;
    double totalGord = 0;
    double totalFib  = 0;

    final refeicaoIds = [
      '${uid}_Café_da_Manhã',
      '${uid}_Almoço',
      '${uid}_Jantar',
    ];

    for (final id in refeicaoIds) {
      final doc = await FirebaseFirestore.instance
          .collection('refeicoes_usuario')
          .doc(id)
          .get();
      if (doc.exists) {
        final d = doc.data() as Map<String, dynamic>;
        totalCal  += (d['totalCalorias'] ?? 0).toDouble();
        totalCarb += (d['totalCarb']     ?? 0).toDouble();
        totalProt += (d['totalProt']     ?? 0).toDouble();
        totalGord += (d['totalGord']     ?? 0).toDouble();
        totalFib  += (d['totalFib']      ?? 0).toDouble();
      }
    }

    final Map<String, List<Map<String, dynamic>>> itensRefeicoes = {};
    final nomes = ['Café da Manhã', 'Almoço', 'Jantar'];
    for (final nome in nomes) {
      final docId = '${uid}_${nome.replaceAll(' ', '_')}';
      final itensSnap = await FirebaseFirestore.instance
          .collection('refeicoes_usuario')
          .doc(docId)
          .collection('itens')
          .get();
      itensRefeicoes[nome] = itensSnap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => _DialogFavoritar(
        uid: uid,
        totalCal: totalCal,
        totalCarb: totalCarb,
        totalProt: totalProt,
        totalGord: totalGord,
        totalFib: totalFib,
        itensRefeicoes: itensRefeicoes,
      ),
    );
  }

  Future<void> _abrirDialogMinhasDietas(BuildContext context) async {
    final uid = _uid;
    if (uid == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetMinhasDietas(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Refeicoes',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Salvar como dieta favorita',
              child: IconButton(
                onPressed: _abrirDialogFavoritar,
                icon: const Icon(Icons.star_border_rounded,
                    color: Colors.amber, size: 28),
              ),
            ),
          ),
        ],
      ),
      body: _buildRefeicoes(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildRefeicoes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Suas Refeicoes',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            'Adicione e organize suas refeicoes diarias',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.star_border_rounded,
                  color: Colors.amber, size: 15),
              SizedBox(width: 4),
              Text(
                'Toque na para salvar esta dieta como favorita',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _abrirDialogMinhasDietas(context),
              icon: const Icon(Icons.star_rounded,
                  color: Colors.amber, size: 18),
              label: const Text(
                'Minhas Dietas',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.amber.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...meals.map((meal) => _buildMealCard(meal)).toList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMealCard(MealData meal) {
    final docId = '${_uid}_${meal.firestoreName}';

    // Lê o doc pai (para o flag 'confirmada') em conjunto com a
    // subcoleção 'itens' (para calcular os totais na hora, evitando negativos).
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refeicoes_usuario')
          .doc(docId)
          .snapshots(),
      builder: (context, snapDoc) {
        bool confirmada = false;
        if (snapDoc.hasData && snapDoc.data!.exists) {
          final d = snapDoc.data!.data() as Map<String, dynamic>;
          confirmada = d['confirmada'] == true;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('refeicoes_usuario')
              .doc(docId)
              .collection('itens')
              .snapshots(),
          builder: (context, snapItens) {
            double totalCal  = 0;
            double totalCarb = 0;
            double totalProt = 0;
            double totalGord = 0;

            if (snapItens.hasData) {
              for (final doc in snapItens.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                totalCal  += (d['calorias'] ?? 0).toDouble();
                totalCarb += (d['carb']     ?? 0).toDouble();
                totalProt += (d['prot']     ?? 0).toDouble();
                totalGord += (d['gord']     ?? 0).toDouble();
              }
            }

            String fmt(double v) => v == v.truncateToDouble()
                ? v.toInt().toString()
                : v.toStringAsFixed(1);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: meal.destinationBuilder),
          ),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: confirmada
                  ? const BorderSide(color: Colors.teal, width: 1.5)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Linha 1: icone + nome + botoes ──────────
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: meal.iconBgColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _buildMealIcon(meal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              meal.timeRange,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: kTeal,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 20),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Linha 2: macros ──────────────────────────
                  Row(
                    children: [
                      _buildNutritionItem('Carb:', '${fmt(totalCarb)}g'),
                      _buildNutritionItem('Prot:', '${fmt(totalProt)}g'),
                      _buildNutritionItem('Gord:', '${fmt(totalGord)}g'),
                      _buildNutritionItem('Calorias:', '${fmt(totalCal)} kcal'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Botao confirmar refeicao ─────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmarRefeicao(
                        mealFirestoreName: meal.firestoreName,
                        totalCal: totalCal,
                        totalProt: totalProt,
                        jaConfirmada: confirmada,
                      ),
                      icon: Icon(
                        confirmada
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        size: 18,
                        color: confirmada ? Colors.white : Colors.teal,
                      ),
                      label: Text(
                        confirmada ? 'Refeicao confirmada' : 'Confirmar refeicao',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: confirmada ? Colors.white : Colors.teal,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            confirmada ? Colors.teal : Colors.teal.shade50,
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

  Widget _buildMealIcon(MealData meal) {
    switch (meal.iconType) {
      case 'twilight':
        return Icon(Icons.wb_twilight, color: meal.iconColor, size: 28);
      case 'sun':
        return Icon(Icons.wb_sunny, color: meal.iconColor, size: 28);
      case 'moon':
        return Icon(Icons.nightlight_round, color: meal.iconColor, size: 28);
      default:
        return Icon(meal.icon, color: meal.iconColor, size: 28);
    }
  }

  Widget _buildNutritionItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: kTeal,
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PerfilPage()),
          );
        }
      },
    );
  }
}

// =============================================================
//  Modelo de dados de cada refeicao
// =============================================================
class MealData {
  final String name;
  final String firestoreName;
  final String timeRange;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String iconType;
  final WidgetBuilder destinationBuilder;

  MealData({
    required this.name,
    required this.firestoreName,
    required this.timeRange,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconType,
    required this.destinationBuilder,
  });
}

// =============================================================
//  Dialog para nomear e salvar a dieta favorita
// =============================================================
class _DialogFavoritar extends StatefulWidget {
  final String uid;
  final double totalCal;
  final double totalCarb;
  final double totalProt;
  final double totalGord;
  final double totalFib;
  final Map<String, List<Map<String, dynamic>>> itensRefeicoes;

  const _DialogFavoritar({
    required this.uid,
    required this.totalCal,
    required this.totalCarb,
    required this.totalProt,
    required this.totalGord,
    required this.totalFib,
    required this.itensRefeicoes,
  });

  @override
  State<_DialogFavoritar> createState() => _DialogFavoritarState();
}

class _DialogFavoritarState extends State<_DialogFavoritar> {
  final _nomeController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um nome para a dieta.')),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      await FirebaseFirestore.instance.collection('dietas_favoritas').add({
        'uid': widget.uid,
        'nome': nome,
        'totalCalorias': widget.totalCal,
        'totalCarb':     widget.totalCarb,
        'totalProt':     widget.totalProt,
        'totalGord':     widget.totalGord,
        'totalFib':      widget.totalFib,
        'itens':         widget.itensRefeicoes,
        'criadaEm':      FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dieta "$nome" salva com sucesso!'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.star_rounded, color: Colors.amber),
          SizedBox(width: 8),
          Text('Salvar dieta', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Dê um nome para esta combinacao de refeicoes:',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nomeController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ex: Dieta low-carb',
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('Salvar',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// =============================================================
//  Bottom Sheet de dietas favoritas
// =============================================================
class _BottomSheetMinhasDietas extends StatefulWidget {
  final String uid;
  const _BottomSheetMinhasDietas({required this.uid});

  @override
  State<_BottomSheetMinhasDietas> createState() =>
      _BottomSheetMinhasDietasState();
}

class _BottomSheetMinhasDietasState
    extends State<_BottomSheetMinhasDietas> {
  String? _aderindoId;

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _confirmarAdesao(
      BuildContext context, Map<String, dynamic> data, String docId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aderir a esta dieta?'),
        content: const Text(
            'Os alimentos desta dieta serao adicionados as suas refeicoes de hoje.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aderir',
                  style: TextStyle(color: Colors.teal))),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _aderindoId = docId);

    try {
      final itens =
          (data['itens'] as Map<String, dynamic>?) ?? {};
      // Chaves devem bater EXATAMENTE com as usadas ao salvar em _abrirDialogFavoritar
      // onde itensRefeicoes é indexado por ['Café da Manhã'], ['Almoço'], ['Jantar']
      final refeicaoMap = {
        'Café da Manhã': 'Café_da_Manhã',
        'Almoço':        'Almoço',
        'Jantar':        'Jantar',
      };

      final db = FirebaseFirestore.instance;

      for (final entry in refeicaoMap.entries) {
        final nomeExib     = entry.key;
        final nomeFirestore = entry.value;
        final refeicaoDocId = '${widget.uid}_$nomeFirestore';
        final refeicaoRef   = db.collection('refeicoes_usuario').doc(refeicaoDocId);

        // ── 1. LIMPA itens existentes em lote ─────────────────
        final itensAtuais = await refeicaoRef.collection('itens').get();
        final batch = db.batch();
        for (final doc in itensAtuais.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // ── 2. Zera os totais do doc pai ───────────────────────
        await refeicaoRef.set({
          'totalCalorias': 0,
          'totalCarb':     0,
          'totalProt':     0,
          'totalGord':     0,
          'totalFib':      0,
          'confirmada':    false,
          'calConfirmada': 0,
          'protConfirmada': 0,
        }, SetOptions(merge: true));

        // ── 3. Insere os itens da dieta selecionada ────────────
        final listaItens = (itens[nomeExib] as List<dynamic>?) ?? [];
        double novaCal  = 0, novaCarb = 0, novaProt = 0;
        double novaGord = 0, novaFib  = 0;

        for (final item in listaItens) {
          final itemMap = Map<String, dynamic>.from(item as Map)
            // Remove timestamp antigo para evitar conflito
            ..remove('adicionadoEm');
          itemMap['adicionadoEm'] = FieldValue.serverTimestamp();

          await refeicaoRef.collection('itens').add(itemMap);

          novaCal  += (itemMap['calorias'] ?? 0).toDouble();
          novaCarb += (itemMap['carb']     ?? 0).toDouble();
          novaProt += (itemMap['prot']     ?? 0).toDouble();
          novaGord += (itemMap['gord']     ?? 0).toDouble();
          novaFib  += (itemMap['fib']      ?? 0).toDouble();
        }

        // ── 4. Atualiza totais com os valores reais inseridos ──
        await refeicaoRef.set({
          'totalCalorias': novaCal,
          'totalCarb':     novaCarb,
          'totalProt':     novaProt,
          'totalGord':     novaGord,
          'totalFib':      novaFib,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dieta aplicada com sucesso!'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao aderir. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _aderindoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Minhas Dietas',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'Toque em "Aderir" para aplicar uma dieta salva',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('dietas_favoritas')
                      .where('uid', isEqualTo: widget.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: kTeal));
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star_border_rounded,
                                size: 52, color: Color(0xFFCCCCCC)),
                            SizedBox(height: 12),
                            Text('Nenhuma dieta salva ainda',
                                style: TextStyle(
                                    fontSize: 15, color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data =
                            doc.data() as Map<String, dynamic>;
                        final nome =
                            data['nome'] as String? ?? 'Sem nome';
                        final cal =
                            (data['totalCalorias'] ?? 0).toDouble();
                        final carb =
                            (data['totalCarb'] ?? 0).toDouble();
                        final prot =
                            (data['totalProt'] ?? 0).toDouble();
                        final gord =
                            (data['totalGord'] ?? 0).toDouble();
                        final isLoading = _aderindoId == doc.id;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF9E0),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber,
                                          size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(nome,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87)),
                                    ),
                                    SizedBox(
                                      height: 36,
                                      child: ElevatedButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => _confirmarAdesao(
                                                context, data, doc.id),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kTeal,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      10)),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14),
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2),
                                              )
                                            : const Text('Aderir',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFA),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _macroItem(
                                          '${_fmt(cal)} kcal', 'Cal', kTeal),
                                      _macroItem(
                                          '${_fmt(carb)}g', 'Carb', Colors.orange),
                                      _macroItem(
                                          '${_fmt(prot)}g', 'Prot', Colors.blue),
                                      _macroItem(
                                          '${_fmt(gord)}g', 'Gord', Colors.purple),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _macroItem(String valor, String label, Color cor) {
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
}

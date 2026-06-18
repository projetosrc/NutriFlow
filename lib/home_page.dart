// =============================================================
//  home_page.dart — NutriFlow
//
//  CORRECCAO: le os ITENS de cada refeicao diretamente das
//  subcolecoes (igual ao refeicoes_screen), em vez de depender
//  dos campos totalCalorias/totalCarb do doc pai, que podem
//  estar desatualizados ou nunca foram escritos.
//
//  IDs usados (identicos ao refeicoes_screen):
//    {uid}_Cafe_da_Manha  /itens
//    {uid}_Almoco         /itens
//    {uid}_Jantar         /itens
// =============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'water_calculation_page.dart';
import 'refeicoes_screen.dart';
import 'minha_dieta_screen.dart';
import 'perfil_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Nomes dos documentos de refeicao - identicos ao refeicoes_screen
  // ATENCAO: estes strings devem ser byte-a-byte identicos aos usados
  // em refeicoes_screen.dart (firestoreName).
  static const List<String> _firestoreNames = [
    'Caf\u00e9_da_Manh\u00e3',  // Café_da_Manhã
    'Almo\u00e7o',              // Almoço
    'Jantar',
  ];

  Stream<QuerySnapshot> _itensStream(String uid, String name) {
    return FirebaseFirestore.instance
        .collection('refeicoes_usuario')
        .doc('${uid}_$name')
        .collection('itens')
        .snapshots();
  }

  double _soma(QuerySnapshot snap, String campo) {
    double total = 0;
    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      total += (d[campo] ?? 0).toDouble();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dieta',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Refei\u00e7\u00f5es'),
            const SizedBox(height: 8.0),
            _buildMealsSummaryCard(context),
            const SizedBox(height: 24.0),
            _buildSectionTitle('Dietas modelo'),
            const SizedBox(height: 8.0),
            _buildModelDietsCard(context),
            const SizedBox(height: 24.0),
            _buildSectionTitle('H\u00e1bitos do dia'),
            const SizedBox(height: 8.0),
            _buildWaterConsumptionCard(context),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PerfilPage()),
            ).then((_) => setState(() => _currentIndex = 0));
            setState(() => _currentIndex = 1);
          } else {
            setState(() => _currentIndex = 0);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Dieta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildMealsSummaryCard(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _itensStream(uid, _firestoreNames[0]),
      builder: (context, snapCafe) {
        return StreamBuilder<QuerySnapshot>(
          stream: _itensStream(uid, _firestoreNames[1]),
          builder: (context, snapAlmoco) {
            return StreamBuilder<QuerySnapshot>(
              stream: _itensStream(uid, _firestoreNames[2]),
              builder: (context, snapJantar) {

                final carregando =
                    snapCafe.connectionState   == ConnectionState.waiting &&
                    snapAlmoco.connectionState == ConnectionState.waiting &&
                    snapJantar.connectionState == ConnectionState.waiting;

                double totalCal  = 0;
                double totalCarb = 0;
                double totalProt = 0;
                double totalGord = 0;
                double totalFib  = 0;

                if (snapCafe.hasData) {
                  totalCal  += _soma(snapCafe.data!, 'calorias');
                  totalCarb += _soma(snapCafe.data!, 'carb');
                  totalProt += _soma(snapCafe.data!, 'prot');
                  totalGord += _soma(snapCafe.data!, 'gord');
                  totalFib  += _soma(snapCafe.data!, 'fib');
                }
                if (snapAlmoco.hasData) {
                  totalCal  += _soma(snapAlmoco.data!, 'calorias');
                  totalCarb += _soma(snapAlmoco.data!, 'carb');
                  totalProt += _soma(snapAlmoco.data!, 'prot');
                  totalGord += _soma(snapAlmoco.data!, 'gord');
                  totalFib  += _soma(snapAlmoco.data!, 'fib');
                }
                if (snapJantar.hasData) {
                  totalCal  += _soma(snapJantar.data!, 'calorias');
                  totalCarb += _soma(snapJantar.data!, 'carb');
                  totalProt += _soma(snapJantar.data!, 'prot');
                  totalGord += _soma(snapJantar.data!, 'gord');
                  totalFib  += _soma(snapJantar.data!, 'fib');
                }

                String fmt(double v) => v == v.truncateToDouble()
                    ? v.toInt().toString()
                    : v.toStringAsFixed(1);

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RefeicoeScreen()),
                  ),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              carregando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.teal),
                                    )
                                  : Text(
                                      '${fmt(totalCal)} kcal',
                                      style: const TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w600),
                                    ),
                              FloatingActionButton.small(
                                heroTag: 'fab_home',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const RefeicoeScreen()),
                                ),
                                backgroundColor: Colors.teal,
                                child: const Icon(Icons.add,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              _buildNutrientItem('Carb:',
                                  carregando ? '-' : '${fmt(totalCarb)}g'),
                              _buildNutrientItem('Prot:',
                                  carregando ? '-' : '${fmt(totalProt)}g'),
                              _buildNutrientItem('Gord:',
                                  carregando ? '-' : '${fmt(totalGord)}g'),
                              _buildNutrientItem('Fib:',
                                  carregando ? '-' : '${fmt(totalFib)}g'),
                            ],
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
      },
    );
  }

  Widget _buildNutrientItem(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
        Text(value,
            style: const TextStyle(
                fontSize: 16.0, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20.0,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildModelDietsCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MinhaDietaScreen()),
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  FaIcon(FontAwesomeIcons.appleWhole,
                      color: Colors.teal, size: 16),
                  SizedBox(width: 8.0),
                  Text('Minhas dietas',
                      style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MinhaDietaScreen()),
                ),
                child: const Text('Ver tudo >',
                    style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterConsumptionCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WaterCalculationPage()),
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.water_drop_outlined,
                  color: Colors.teal, size: 16),
              SizedBox(width: 8.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Consumo de \u00e1gua',
                      style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 4.0),
                  Text('Consumo de \u00e1gua indicado',
                      style: TextStyle(
                          fontSize: 14.0, color: Colors.teal)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
//  perfil_page.dart — NutriFlow
//
//  NOVO: "Consumido" le consumidoCalorias e consumidoProteina
//  do Firestore em tempo real via StreamBuilder.
//  Esses campos sao atualizados pela tela de Refeicoes
//  quando o usuario confirma uma refeicao.
// =============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

// ---------------------------------------------
//  MODELO DE DADOS DO PERFIL
// ---------------------------------------------
class PerfilUsuario {
  final String nome;
  final String email;
  final int metaCalorica;
  final int proteina;

  const PerfilUsuario({
    required this.nome,
    required this.email,
    required this.metaCalorica,
    required this.proteina,
  });

  factory PerfilUsuario.fromFirestore(Map<String, dynamic> data) {
    return PerfilUsuario(
      nome: data['nome'] ?? '',
      email: data['email'] ?? '',
      metaCalorica: (data['metaCalorica'] ?? 2000) as int,
      proteina: (data['proteina'] ?? 150) as int,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'email': email,
      'metaCalorica': metaCalorica,
      'proteina': proteina,
    };
  }

  PerfilUsuario copyWith({
    String? nome,
    String? email,
    int? metaCalorica,
    int? proteina,
  }) {
    return PerfilUsuario(
      nome: nome ?? this.nome,
      email: email ?? this.email,
      metaCalorica: metaCalorica ?? this.metaCalorica,
      proteina: proteina ?? this.proteina,
    );
  }
}

// ---------------------------------------------
//  WIDGET PRINCIPAL
// ---------------------------------------------
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late final DocumentReference _docRef;

  PerfilUsuario? _perfil;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _docRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_user!.uid);
    _carregarOuCriarPerfil();
  }

  // ---------------------------------------------
  //  READ / CREATE
  // ---------------------------------------------
  Future<void> _carregarOuCriarPerfil() async {
    try {
      DocumentSnapshot? snapshot;

      try {
        snapshot = await _docRef.get(const GetOptions(source: Source.cache));
      } catch (_) {
        snapshot = null;
      }

      if (snapshot == null || !snapshot.exists) {
        snapshot = await _docRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8), onTimeout: () {
          throw Exception('Timeout ao conectar ao Firestore.');
        });
      }

      if (snapshot.exists) {
        if (mounted) {
          setState(() {
            _perfil = PerfilUsuario.fromFirestore(
              snapshot!.data() as Map<String, dynamic>,
            );
            _isLoading = false;
          });
        }
      } else {
        final novoPerfil = PerfilUsuario(
          nome: _user!.displayName ?? 'Usuario NutriFlow',
          email: _user!.email ?? '',
          metaCalorica: 2000,
          proteina: 150,
        );

        _docRef.set({
          ...novoPerfil.toFirestore(),
          'consumidoCalorias': 0,
          'consumidoProteina': 0,
          'criadoEm': FieldValue.serverTimestamp(),
        }).catchError((e) => debugPrint('Erro ao criar perfil: $e'));

        if (mounted) {
          setState(() {
            _perfil = novoPerfil;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      final perfilFallback = PerfilUsuario(
        nome: _user?.displayName ?? 'Usuario NutriFlow',
        email: _user?.email ?? '',
        metaCalorica: 2000,
        proteina: 150,
      );
      if (mounted) {
        setState(() {
          _perfil = perfilFallback;
          _isLoading = false;
        });
        _showMessage('Sem conexao com servidor. Exibindo dados locais.');
      }
    }
  }

  // ---------------------------------------------
  //  UPDATE
  //  Usa StatefulWidget próprio para o sheet —
  //  evita o erro "_dependents.isEmpty is not true"
  //  causado pelo builder ser chamado múltiplas vezes
  //  quando o teclado aparece/desaparece.
  // ---------------------------------------------
  Future<void> _editarPerfil() async {
    if (_perfil == null) return;

    final PerfilUsuario? atualizado =
        await showModalBottomSheet<PerfilUsuario>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditarPerfilSheet(perfil: _perfil!),
    );

    if (atualizado != null && mounted) {
      await _salvarPerfil(atualizado);
      await _user?.updateDisplayName(atualizado.nome);
    }
  }

  Future<void> _salvarPerfil(PerfilUsuario atualizado) async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      await _docRef.set(
        {
          ...atualizado.toFirestore(),
          'atualizadoEm': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() {
        _perfil = atualizado;
        _isSaving = false;
      });
      _showMessage('Perfil atualizado com sucesso!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Erro ao salvar: $e');
    }
  }

  // ---------------------------------------------
  //  DELETE
  // ---------------------------------------------
  Future<void> _excluirConta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Tem certeza? Esta acao e irreversivel.\n'
          'Todos os seus dados serao apagados permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _docRef.delete();
      await _user!.delete();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showMessage('Por seguranca, faca login novamente antes de excluir.');
      } else {
        _showMessage('Erro ao excluir conta: ${e.message}');
      }
    } catch (e) {
      _showMessage('Erro ao excluir: $e');
    }
  }

  // ---------------------------------------------
  //  LOGOUT
  // ---------------------------------------------
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---------------------------------------------
  //  BUILD PRINCIPAL
  // ---------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Perfil',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.teal),
              tooltip: 'Editar perfil',
              onPressed: _editarPerfil,
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.teal),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _perfil == null
              ? const Center(child: Text('Erro ao carregar perfil.'))
              : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu), label: 'Dieta'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: (index) {
          if (index == 0) Navigator.pop(context);
        },
      ),
    );
  }

  // ---------------------------------------------
  //  CORPO — StreamBuilder para consumido em tempo real
  //
  //  Lê consumidoCalorias e consumidoProteina do documento
  //  do próprio usuário em 'usuarios/{uid}'.
  //  Esses campos são incrementados/decrementados pelo botão
  //  "Confirmar refeição" na RefeicoeScreen.
  //  Ao desmarcar, os valores voltam exatamente ao que eram
  //  antes da confirmação.
  // ---------------------------------------------
  Widget _buildBody() {
    final p   = _perfil!;
    final uid = _user!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        double consumidoCal  = 0;
        double consumidoProt = 0;

        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map<String, dynamic>;
          consumidoCal  = (d['consumidoCalorias'] ?? 0).toDouble();
          consumidoProt = (d['consumidoProteina'] ?? 0).toDouble();
        }

        // Garante que nunca seja negativo por desincronismo
        if (consumidoCal  < 0) consumidoCal  = 0;
        if (consumidoProt < 0) consumidoProt = 0;

        // Kcal restantes (nunca negativo)
        final kcalRestantes = (p.metaCalorica - consumidoCal)
            .clamp(0, p.metaCalorica.toDouble())
            .toInt();

        // Progresso de 0.0 a 1.0 para o arco verde
        final progresso =
            (consumidoCal / p.metaCalorica).clamp(0.0, 1.0);

        String fmt(double v) => v == v.truncateToDouble()
            ? v.toInt().toString()
            : v.toStringAsFixed(1);

        return _buildBodyContent(
          p: p,
          consumidoCal: consumidoCal,
          consumidoProt: consumidoProt,
          kcalRestantes: kcalRestantes,
          progresso: progresso,
          fmt: fmt,
        );
      },
    );
  }

  Widget _buildBodyContent({
    required PerfilUsuario p,
    required double consumidoCal,
    required double consumidoProt,
    required int kcalRestantes,
    required double progresso,
    required String Function(double) fmt,
  }) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // -- CARD AVATAR + NOME + EMAIL --
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 28, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE6F7F5),
                            border:
                                Border.all(color: Colors.teal, width: 2.5),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.teal, size: 44),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          p.nome,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'Meu corpo',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
              const SizedBox(height: 12),

              // -- Card: meta + consumido + proteina --
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Meta diaria + círculo com arco de progresso
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Meta diária',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                '${p.metaCalorica.toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (m) => '${m[1]}.',
                                )} kcal',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                          // ── CÍRCULO COM ARCO DE PROGRESSO VERDE ───────
                          // CustomPaint desenha:
                          //   1. Arco cinza de fundo (sempre completo)
                          //   2. Arco verde proporcional ao % consumido
                          //   3. Texto central com kcal restantes
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: CustomPaint(
                              painter: _CaloriasArcPainter(
                                progresso: progresso, // 0.0 a 1.0
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      kcalRestantes.toString().replaceAllMapped(
                                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                        (m) => '${m[1]}.',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Text(
                                      'Restantes',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // ── FIM DO CÍRCULO ─────────────────────────────
                        ],
                      ),

                      const Divider(height: 28),

                      // Consumido — atualiza em tempo real
                      const Text('Consumido',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '${fmt(consumidoCal)} kcal',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Proteina consumida / meta
                      const Text('Proteína',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey)),
                      const Divider(thickness: 1.5, color: Color(0xFFE5E7EB)),
                      Text(
                        '${fmt(consumidoProt)}g / ${p.proteina}g',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // -- BOTAO LOGOUT --
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.teal),
                  label: const Text('Sair da conta',
                      style: TextStyle(
                          color: Colors.teal,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // -- BOTAO EXCLUIR CONTA --
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _excluirConta,
                  icon: const Icon(Icons.delete_forever_outlined,
                      color: Colors.red),
                  label: const Text('Excluir minha conta',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
  }
}

// =============================================================
//  SHEET DE EDIÇÃO — StatefulWidget próprio
//  Gerencia seus próprios TextEditingControllers para evitar
//  o erro "_dependents.isEmpty is not true" que ocorre quando
//  o builder do showModalBottomSheet é rechamado ao aparecer
//  o teclado virtual.
// =============================================================
class _EditarPerfilSheet extends StatefulWidget {
  final PerfilUsuario perfil;
  const _EditarPerfilSheet({required this.perfil});

  @override
  State<_EditarPerfilSheet> createState() => _EditarPerfilSheetState();
}

class _EditarPerfilSheetState extends State<_EditarPerfilSheet> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _caloCtrl;
  late final TextEditingController _protCtrl;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.perfil.nome);
    _caloCtrl = TextEditingController(text: widget.perfil.metaCalorica.toString());
    _protCtrl = TextEditingController(text: widget.perfil.proteina.toString());
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _caloCtrl.dispose();
    _protCtrl.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController ctrl, TextInputType type) {
    final isNumeric = type == TextInputType.number;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: type,
            // Bloqueia qualquer caractere não numérico nos campos de número
            inputFormatters: isNumeric
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Editar Perfil',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _field('Nome', _nomeCtrl, TextInputType.name),
            _field('Meta calórica (kcal)', _caloCtrl, TextInputType.number),
            _field('Proteína (g)', _protCtrl, TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final resultado = widget.perfil.copyWith(
                    nome: _nomeCtrl.text.trim(),
                    metaCalorica: int.tryParse(_caloCtrl.text) ??
                        widget.perfil.metaCalorica,
                    proteina: int.tryParse(_protCtrl.text) ??
                        widget.perfil.proteina,
                  );
                  Navigator.pop(context, resultado);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Salvar alterações',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// =============================================================
//  CUSTOM PAINTER: ARCO DE PROGRESSO DE CALORIAS
//
//  Desenha dois arcos concêntricos:
//    1. Arco cinza claro de fundo (círculo completo)
//    2. Arco verde preenchido proporcionalmente ao % consumido
//
//  progresso: 0.0 = vazio (nenhuma caloria consumida)
//             1.0 = completo (meta atingida)
//
//  O arco começa no topo (-90°) e cresce no sentido horário.
// =============================================================
class _CaloriasArcPainter extends CustomPainter {
  final double progresso; // 0.0 a 1.0

  const _CaloriasArcPainter({required this.progresso});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 5;
    const strokeWidth = 7.0;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── 1. ARCO DE FUNDO (cinza) — círculo completo ───────────
    final paintFundo = Paint()
      ..color = const Color(0xFFE5E7EB) // Cinza claro
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * 3.14159, false, paintFundo);

    // ── 2. ARCO DE PROGRESSO (verde teal) ────────────────────
    // Só desenha se houver progresso (evita arco de tamanho 0)
    if (progresso > 0) {
      final paintProgresso = Paint()
        ..color = Colors.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round; // Ponta arredondada

      // Ângulo inicial: -π/2 (topo do círculo)
      // Ângulo varrido: proporcional ao progresso (max 2π = círculo completo)
      const startAngle = -3.14159 / 2; // -90° = topo
      final sweepAngle = 2 * 3.14159 * progresso;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paintProgresso);
    }
  }

  @override
  bool shouldRepaint(_CaloriasArcPainter old) =>
      old.progresso != progresso;
}

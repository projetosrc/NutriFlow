// =============================================================
//  adicionar_alimento_screen.dart
//  Tela de busca e adição de alimentos — NutriFlow
//
//  MUDANÇA: ao tocar em "+" abre um bottom sheet onde o usuário
//  escolhe a quantidade em gramas (mínimo 10g, incrementos de 10g).
//  Os macros e calorias são recalculados proporcionalmente antes
//  de salvar no Firestore.
// =============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdicionarAlimentoScreen extends StatefulWidget {
  final String nomeRefeicao;

  const AdicionarAlimentoScreen({
    super.key,
    required this.nomeRefeicao,
  });

  @override
  State<AdicionarAlimentoScreen> createState() =>
      _AdicionarAlimentoScreenState();
}

class _AdicionarAlimentoScreenState extends State<AdicionarAlimentoScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _todosAlimentos = [];
  List<Map<String, dynamic>> _alimentosFiltrados = [];
  bool _isLoading = true;
  String? _adicionandoId;

  @override
  void initState() {
    super.initState();
    _carregarAlimentos();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filtrar);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  READ — Carrega alimentos do Firestore
  //  Mantém os valores por 100g para recalcular
  //  depois com base nas gramas escolhidas.
  // ─────────────────────────────────────────────
  Future<void> _carregarAlimentos() async {
    try {
      final snapshot = await _firestore.collection('alimentos').get();

      final lista = snapshot.docs.map((doc) {
        final d = doc.data();

        double toD(dynamic v) => (v is num) ? v.toDouble() : 0.0;
        int    toI(dynamic v) => (v is num) ? v.toInt()    : 0;

        // Valores BASE por 100g — usados para recalcular proporcionalmente
        final carb100 = toD(d['carboidratos_por_100g']);
        final prot100 = toD(d['proteinas_por_100g']);
        final gord100 = toD(d['gorduras_por_100g']);
        final fib100  = toD(d['fibras_por_100g']);
        final cal100  = toD(d['calorias_por_100g']);
        final porcPad = toI(d['porcao_padrao_g'] ?? 100);

        return {
          'id':       doc.id,
          'nome':     d['nome'] ?? '',
          // Exibe a porção padrão no card, mas permite alterar no pop-up
          'porcao':   '${porcPad}g',
          // Valores por 100g — guardados para proporcionalidade
          'cal100':   cal100,
          'carb100':  carb100,
          'prot100':  prot100,
          'gord100':  gord100,
          'fib100':   fib100,
          // Valores calculados para a porção padrão (exibição no card)
          'calorias': (cal100  * porcPad / 100).round(),
          'carb':     carb100  * porcPad / 100,
          'prot':     prot100  * porcPad / 100,
          'gord':     gord100  * porcPad / 100,
          'fib':      fib100   * porcPad / 100,
        };
      }).toList();

      lista.sort((a, b) =>
          (a['nome'] as String).compareTo(b['nome'] as String));

      if (mounted) {
        setState(() {
          _todosAlimentos    = lista;
          _alimentosFiltrados = lista;
          _isLoading         = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Erro ao carregar alimentos: $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  //  FILTRO em tempo real
  // ─────────────────────────────────────────────
  void _filtrar() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _alimentosFiltrados = query.isEmpty
          ? _todosAlimentos
          : _todosAlimentos
              .where((a) =>
                  (a['nome'] as String).toLowerCase().contains(query))
              .toList();
    });
  }

  // ─────────────────────────────────────────────
  //  POPUP — Seleção de gramas
  //  Abre um bottom sheet com contador +/- de 10g.
  //  Mostra preview dos macros em tempo real.
  //  Mínimo: 10g.
  // ─────────────────────────────────────────────
  Future<void> _mostrarPopupGramas(Map<String, dynamic> alimento) async {
    // Extrai porção padrão (ex: "100g" → 100)
    final String porcaoStr = alimento['porcao'] as String;
    final int porcaoPadrao =
        int.tryParse(porcaoStr.replaceAll('g', '')) ?? 100;

    // Abre o bottom sheet; o resultado é a quantidade escolhida ou null
    final int? gramasSelecionadas = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetGramas(
        alimento: alimento,
        porcaoInicial: porcaoPadrao,
      ),
    );

    // Usuário fechou sem confirmar
    if (gramasSelecionadas == null) return;

    // ── Recalcula macros proporcionalmente ──────
    final double fator = gramasSelecionadas / 100.0;
    final double cal100  = (alimento['cal100']  as num).toDouble();
    final double carb100 = (alimento['carb100'] as num).toDouble();
    final double prot100 = (alimento['prot100'] as num).toDouble();
    final double gord100 = (alimento['gord100'] as num).toDouble();
    final double fib100  = (alimento['fib100']  as num).toDouble();

    final Map<String, dynamic> alimentoAjustado = {
      ...alimento,
      'porcao':   '${gramasSelecionadas}g',
      'calorias': (cal100  * fator).round(),
      'carb':     carb100  * fator,
      'prot':     prot100  * fator,
      'gord':     gord100  * fator,
      'fib':      fib100   * fator,
    };

    await _adicionarAlimento(alimentoAjustado);
  }

  // ─────────────────────────────────────────────
  //  CREATE — Salva alimento na refeição
  // ─────────────────────────────────────────────
  Future<void> _adicionarAlimento(Map<String, dynamic> alimento) async {
    if (_user == null) return;
    setState(() => _adicionandoId = alimento['id']);

    try {
      final refeicaoDocId =
          '${_user!.uid}_${widget.nomeRefeicao.replaceAll(' ', '_')}';

      final refeicaoRef = _firestore
          .collection('refeicoes_usuario')
          .doc(refeicaoDocId);

      await refeicaoRef.collection('itens').add({
        'alimentoId':   alimento['id'],
        'nome':         alimento['nome'],
        'porcao':       alimento['porcao'],
        'calorias':     alimento['calorias'],
        'carb':         alimento['carb'],
        'prot':         alimento['prot'],
        'gord':         alimento['gord'],
        'fib':          alimento['fib'],
        'adicionadoEm': FieldValue.serverTimestamp(),
      });

      await refeicaoRef.set({
        'nomeRefeicao':  widget.nomeRefeicao,
        'uid':           _user!.uid,
        'totalCalorias': FieldValue.increment(alimento['calorias']),
        'totalCarb':     FieldValue.increment(alimento['carb']),
        'totalProt':     FieldValue.increment(alimento['prot']),
        'totalGord':     FieldValue.increment(alimento['gord']),
        'totalFib':      FieldValue.increment(alimento['fib']),
      }, SetOptions(merge: true));

      if (mounted) {
        _showMessage('${alimento['nome']} (${alimento['porcao']}) adicionado!');
      }
    } catch (e) {
      if (mounted) _showMessage('Erro ao adicionar: $e');
    } finally {
      if (mounted) setState(() => _adicionandoId = null);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
        ),
        title: Text(
          widget.nomeRefeicao,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Buscar alimentos...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Selecione os alimentos consumidos e acompanhe automaticamente suas calorias e nutrientes para manter uma alimentação equilibrada.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.teal, height: 1.5),
                  ),
                ),
                Expanded(
                  child: _alimentosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                _searchCtrl.text.isEmpty
                                    ? 'Nenhum alimento cadastrado.\nVerifique a coleção "alimentos" no Firestore.'
                                    : 'Nenhum resultado para "${_searchCtrl.text}".',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _alimentosFiltrados.length,
                          itemBuilder: (context, index) =>
                              _buildAlimentoCard(
                                  _alimentosFiltrados[index]),
                        ),
                ),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────
  //  Card de alimento na lista
  // ─────────────────────────────────────────────
  Widget _buildAlimentoCard(Map<String, dynamic> alimento) {
    final bool adicionando = _adicionandoId == alimento['id'];

    String fmt(double v) =>
        v == v.truncateToDouble()
            ? v.toInt().toString()
            : v.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alimento['nome'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${alimento['porcao']} · ${alimento['calorias']} kcal',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _macroLabel('Carb'),
                      _macroLabel('Prot'),
                      _macroLabel('Gord'),
                      _macroLabel('Fib'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _macroValue('${fmt(alimento['carb'])}g'),
                      _macroValue('${fmt(alimento['prot'])}g'),
                      _macroValue('${fmt(alimento['gord'])}g'),
                      _macroValue('${fmt(alimento['fib'])}g'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            adicionando
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.teal),
                  )
                : GestureDetector(
                    // ← agora abre o popup de gramas
                    onTap: () => _mostrarPopupGramas(alimento),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 22),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _macroLabel(String label) => SizedBox(
        width: 60,
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.teal,
                fontWeight: FontWeight.w500)),
      );

  Widget _macroValue(String value) => SizedBox(
        width: 60,
        child: Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      );
}

// =============================================================
//  _BottomSheetGramas
//  Widget separado (StatefulWidget) para gerenciar o contador
//  de gramas e o preview de macros em tempo real.
// =============================================================
class _BottomSheetGramas extends StatefulWidget {
  final Map<String, dynamic> alimento;
  final int porcaoInicial;

  const _BottomSheetGramas({
    required this.alimento,
    required this.porcaoInicial,
  });

  @override
  State<_BottomSheetGramas> createState() => _BottomSheetGramasState();
}

class _BottomSheetGramasState extends State<_BottomSheetGramas> {
  static const int _passo   = 10; // incremento/decremento
  static const int _minGram = 10; // mínimo permitido

  late int _gramas;

  @override
  void initState() {
    super.initState();
    // Começa na porção padrão, garantindo que seja múltiplo de 10 e >= 10
    final padrao = widget.porcaoInicial;
    _gramas = (padrao < _minGram)
        ? _minGram
        : (padrao % _passo == 0 ? padrao : ((padrao ~/ _passo) * _passo));
    if (_gramas < _minGram) _gramas = _minGram;
  }

  // Recalcula um macro para a quantidade atual de gramas
  double _calc(String chave100) {
    final double base = (widget.alimento[chave100] as num).toDouble();
    return base * _gramas / 100;
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final double cal  = _calc('cal100');
    final double carb = _calc('carb100');
    final double prot = _calc('prot100');
    final double gord = _calc('gord100');
    final double fib  = _calc('fib100');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Alça visual ────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Nome do alimento ───────────────────────────────────
          Text(
            widget.alimento['nome'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Valores calculados por 100g',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // ── Contador de gramas ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAFA),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botão −
                _CounterButton(
                  icon: Icons.remove,
                  enabled: _gramas > _minGram,
                  onTap: () {
                    if (_gramas > _minGram) {
                      setState(() => _gramas -= _passo);
                    }
                  },
                ),

                // Valor central
                Column(
                  children: [
                    Text(
                      '$_gramas',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'gramas',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.teal,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'mínimo $_minGram g · incremento $_passo g',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),

                // Botão +
                _CounterButton(
                  icon: Icons.add,
                  enabled: true,
                  onTap: () => setState(() => _gramas += _passo),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Preview de macros ──────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              children: [
                _MacroPreview(
                    label: 'Calorias',
                    value: '${_fmt(cal)} kcal',
                    color: Colors.orange),
                _MacroPreview(
                    label: 'Carb',
                    value: '${_fmt(carb)}g',
                    color: Colors.teal),
                _MacroPreview(
                    label: 'Prot',
                    value: '${_fmt(prot)}g',
                    color: Colors.teal),
                _MacroPreview(
                    label: 'Gord',
                    value: '${_fmt(gord)}g',
                    color: Colors.teal),
                _MacroPreview(
                    label: 'Fib',
                    value: '${_fmt(fib)}g',
                    color: Colors.teal),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Botões de ação ─────────────────────────────────────
          Row(
            children: [
              // Cancelar
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Confirmar
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _gramas),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(
                    'Adicionar $_gramas g',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Botão arredondado +/- ──────────────────────────────────────
class _CounterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CounterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? Colors.teal : const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon,
            color: enabled ? Colors.white : Colors.grey, size: 26),
      ),
    );
  }
}

// ── Preview de macro individual ────────────────────────────────
class _MacroPreview extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroPreview({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

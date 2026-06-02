// adicionar_alimento_screen.dart
// Tela de busca e adição de alimentos — NutriFlow
//
// Ao tocar no "+" de um alimento, abre um bottom sheet para o
// usuário escolher a quantidade em gramas. Os macros são
// recalculados proporcionalmente antes de salvar.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdicionarAlimentoScreen extends StatefulWidget {
  final String nomeRefeicao;

  const AdicionarAlimentoScreen({super.key, required this.nomeRefeicao});

  @override
  State<AdicionarAlimentoScreen> createState() => _AdicionarAlimentoScreenState();
}

class _AdicionarAlimentoScreenState extends State<AdicionarAlimentoScreen> {
  final _firestore   = FirebaseFirestore.instance;
  final _user        = FirebaseAuth.instance.currentUser;
  final _searchCtrl  = TextEditingController();

  List<Map<String, dynamic>> _todosAlimentos     = [];
  List<Map<String, dynamic>> _alimentosFiltrados = [];
  bool   _isLoading    = true;
  String? _adicionandoId; // id do alimento sendo adicionado no momento

  @override
  void initState() {
    super.initState();
    _carregarAlimentos();
    _searchCtrl.addListener(_filtrar); // filtra em tempo real ao digitar
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filtrar);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── READ: busca todos os alimentos do Firestore ───────────────
  // Guarda os valores por 100g para recalcular depois
  // com base na quantidade que o usuário escolher.
  Future<void> _carregarAlimentos() async {
    try {
      final snapshot = await _firestore.collection('alimentos').get();

      final lista = snapshot.docs.map((doc) {
        final d = doc.data();

        double toD(dynamic v) => v is num ? v.toDouble() : 0.0;
        int    toI(dynamic v) => v is num ? v.toInt()    : 0;

        // valores base por 100g
        final cal100  = toD(d['calorias_por_100g']);
        final carb100 = toD(d['carboidratos_por_100g']);
        final prot100 = toD(d['proteinas_por_100g']);
        final gord100 = toD(d['gorduras_por_100g']);
        final fib100  = toD(d['fibras_por_100g']);
        final porcPad = toI(d['porcao_padrao_g'] ?? 100);

        return {
          'id':    doc.id,
          'nome':  d['nome'] ?? '',
          'porcao': '${porcPad}g',
          // valores por 100g guardados para proporcionalidade
          'cal100':  cal100,
          'carb100': carb100,
          'prot100': prot100,
          'gord100': gord100,
          'fib100':  fib100,
          // valores já calculados para a porção padrão (exibição no card)
          'calorias': (cal100  * porcPad / 100).round(),
          'carb':      carb100 * porcPad / 100,
          'prot':      prot100 * porcPad / 100,
          'gord':      gord100 * porcPad / 100,
          'fib':       fib100  * porcPad / 100,
        };
      }).toList()
        ..sort((a, b) => (a['nome'] as String).compareTo(b['nome'] as String));

      if (mounted) {
        setState(() {
          _todosAlimentos     = lista;
          _alimentosFiltrados = lista;
          _isLoading          = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Erro ao carregar alimentos: $e');
      }
    }
  }

  // filtra a lista pelo texto digitado na busca
  void _filtrar() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _alimentosFiltrados = query.isEmpty
          ? _todosAlimentos
          : _todosAlimentos
              .where((a) => (a['nome'] as String).toLowerCase().contains(query))
              .toList();
    });
  }

  // ── abre o bottom sheet de seleção de gramas ──────────────────
  // o resultado é a quantidade escolhida ou null (cancelou)
  Future<void> _mostrarPopupGramas(Map<String, dynamic> alimento) async {
    final porcaoPadrao = int.tryParse(
            (alimento['porcao'] as String).replaceAll('g', '')) ??
        100;

    final gramasSelecionadas = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetGramas(
        alimento:      alimento,
        porcaoInicial: porcaoPadrao,
      ),
    );

    if (gramasSelecionadas == null) return;

    // recalcula os macros proporcionalmente à quantidade escolhida
    final fator  = gramasSelecionadas / 100.0;
    final ajustado = {
      ...alimento,
      'porcao':   '${gramasSelecionadas}g',
      'calorias': ((alimento['cal100'] as num).toDouble() * fator).round(),
      'carb':      (alimento['carb100'] as num).toDouble() * fator,
      'prot':      (alimento['prot100'] as num).toDouble() * fator,
      'gord':      (alimento['gord100'] as num).toDouble() * fator,
      'fib':       (alimento['fib100']  as num).toDouble() * fator,
    };

    await _adicionarAlimento(ajustado);
  }

  // ── CREATE: salva o alimento na refeição no Firestore ─────────
  Future<void> _adicionarAlimento(Map<String, dynamic> alimento) async {
    if (_user == null) return;
    setState(() => _adicionandoId = alimento['id']);

    try {
      final docId = '${_user!.uid}_${widget.nomeRefeicao.replaceAll(' ', '_')}';
      final refeicaoRef = _firestore.collection('refeicoes_usuario').doc(docId);

      // adiciona o item na subcoleção
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

      // atualiza os totais do doc pai com increment (evita race conditions)
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.teal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
        ),
        title: Text(widget.nomeRefeicao,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        // campo de busca embutido no appbar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Buscar alimentos...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Selecione os alimentos consumidos e acompanhe automaticamente suas calorias e nutrientes para manter uma alimentação equilibrada.',
                    style: TextStyle(fontSize: 13, color: Colors.teal, height: 1.5),
                  ),
                ),
                Expanded(
                  child: _alimentosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                _searchCtrl.text.isEmpty
                                    ? 'Nenhum alimento cadastrado.\nVerifique a coleção "alimentos" no Firestore.'
                                    : 'Nenhum resultado para "${_searchCtrl.text}".',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _alimentosFiltrados.length,
                          itemBuilder: (_, i) =>
                              _buildAlimentoCard(_alimentosFiltrados[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAlimentoCard(Map<String, dynamic> alimento) {
    final adicionando = _adicionandoId == alimento['id'];

    String fmt(double v) => v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFEAF7F4),
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alimento['nome'],
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 3),
                  Text('${alimento['porcao']} · ${alimento['calorias']} kcal',
                      style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 10),
                  // labels e valores dos macros em duas linhas
                  Row(children: ['Carb', 'Prot', 'Gord', 'Fib']
                      .map((l) => _macroLabel(l))
                      .toList()),
                  const SizedBox(height: 2),
                  Row(children: [
                    _macroValue('${fmt(alimento['carb'])}g'),
                    _macroValue('${fmt(alimento['prot'])}g'),
                    _macroValue('${fmt(alimento['gord'])}g'),
                    _macroValue('${fmt(alimento['fib'])}g'),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // botão de adicionar — vira spinner enquanto salva
            adicionando
                ? const SizedBox(
                    width: 40, height: 40,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.teal))
                : GestureDetector(
                    onTap: () => _mostrarPopupGramas(alimento),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                          color: Colors.teal, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
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
            fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w500)),
  );

  Widget _macroValue(String value) => SizedBox(
    width: 60,
    child: Text(value,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
  );
}

// ── Bottom sheet de seleção de gramas ────────────────────────────
// Widget separado para ter seu próprio setState sem afetar a tela principal
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
  static const _passo   = 10;
  static const _minGram = 10;

  late int _gramas;

  @override
  void initState() {
    super.initState();
    // garante que começa num múltiplo de 10 e acima do mínimo
    final p = widget.porcaoInicial;
    _gramas = (p < _minGram)
        ? _minGram
        : (p % _passo == 0 ? p : (p ~/ _passo) * _passo);
  }

  // recalcula um macro para as gramas atuais
  double _calc(String chave) =>
      (widget.alimento[chave] as num).toDouble() * _gramas / 100;

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final cal  = _calc('cal100');
    final carb = _calc('carb100');
    final prot = _calc('prot100');
    final gord = _calc('gord100');
    final fib  = _calc('fib100');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // alça visual do sheet
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2)),
          ),

          Text(widget.alimento['nome'],
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          const Text('Valores calculados por 100g',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 24),

          // contador de gramas com botões +/-
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFF0FAFA),
                borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CounterButton(
                  icon: Icons.remove,
                  enabled: _gramas > _minGram,
                  onTap: () {
                    if (_gramas > _minGram) setState(() => _gramas -= _passo);
                  },
                ),
                Column(
                  children: [
                    Text('$_gramas',
                        style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                            height: 1)),
                    const Text('gramas',
                        style: TextStyle(
                            fontSize: 14, color: Colors.teal, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('mínimo $_minGram g · incremento $_passo g',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                _CounterButton(
                  icon: Icons.add,
                  enabled: true,
                  onTap: () => setState(() => _gramas += _passo),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // preview dos macros calculados em tempo real
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              children: [
                _MacroPreview(label: 'Calorias', value: '${_fmt(cal)} kcal',  color: Colors.orange),
                _MacroPreview(label: 'Carb',     value: '${_fmt(carb)}g',     color: Colors.teal),
                _MacroPreview(label: 'Prot',     value: '${_fmt(prot)}g',     color: Colors.teal),
                _MacroPreview(label: 'Gord',     value: '${_fmt(gord)}g',     color: Colors.teal),
                _MacroPreview(label: 'Fib',      value: '${_fmt(fib)}g',      color: Colors.teal),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // botões de ação
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancelar',
                      style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  // retorna as gramas escolhidas para a tela principal
                  onPressed: () => Navigator.pop(context, _gramas),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text('Adicionar $_gramas g',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// botão animado +/- do contador
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
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: enabled ? Colors.teal : const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: enabled ? Colors.white : Colors.grey, size: 26),
      ),
    );
  }
}

// exibe um macro individual no preview
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
                  fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

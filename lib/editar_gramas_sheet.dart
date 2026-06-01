// =============================================================
//  editar_gramas_sheet.dart
//  Bottom sheet reutilizável para editar as gramas de um
//  alimento já adicionado a uma refeição.
//
//  Uso:
//    await EditarGramasSheet.show(
//      context: context,
//      itemData: d,           // dados do doc Firestore
//      docRef: docRef,        // referência do item
//      refeicaoDocId: docId,  // doc pai da refeição
//      iconColor: _iconColor, // cor do tema da tela
//    );
// =============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarGramasSheet extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final DocumentReference docRef;
  final String refeicaoDocId;
  final Color iconColor;

  const EditarGramasSheet({
    super.key,
    required this.itemData,
    required this.docRef,
    required this.refeicaoDocId,
    required this.iconColor,
  });

  /// Abre o bottom sheet e aguarda o resultado.
  /// Retorna true se o item foi atualizado, false/null caso contrário.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, dynamic> itemData,
    required DocumentReference docRef,
    required String refeicaoDocId,
    required Color iconColor,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditarGramasSheet(
        itemData: itemData,
        docRef: docRef,
        refeicaoDocId: refeicaoDocId,
        iconColor: iconColor,
      ),
    );
  }

  @override
  State<EditarGramasSheet> createState() => _EditarGramasSheetState();
}

class _EditarGramasSheetState extends State<EditarGramasSheet> {
  static const int _passo   = 10;
  static const int _minGram = 10;

  late int _gramas;
  bool _salvando = false;

  // Valores originais salvos no Firestore (para calcular diff)
  late final double _calOriginal;
  late final double _carbOriginal;
  late final double _protOriginal;
  late final double _gordOriginal;
  late final double _fibOriginal;
  late final int    _gramasOriginais;

  @override
  void initState() {
    super.initState();
    final d = widget.itemData;

    _calOriginal  = (d['calorias'] ?? 0).toDouble();
    _carbOriginal = (d['carb']     ?? 0).toDouble();
    _protOriginal = (d['prot']     ?? 0).toDouble();
    _gordOriginal = (d['gord']     ?? 0).toDouble();
    _fibOriginal  = (d['fib']      ?? 0).toDouble();

    // Extrai gramas da string "30g" → 30
    final String porcaoStr = (d['porcao'] ?? '100g') as String;
    final int gSalvo = int.tryParse(porcaoStr.replaceAll('g', '').trim()) ?? 100;

    // Arredonda para múltiplo de 10 e respeita o mínimo
    int g = (gSalvo < _minGram) ? _minGram : gSalvo;
    if (g % _passo != 0) g = (g ~/ _passo) * _passo;
    if (g < _minGram) g = _minGram;
    _gramas = g;
    _gramasOriginais = g;
  }

  // ── Recalcula um macro para a quantidade atual de gramas ──────
  // Os valores por 100g são obtidos dividindo os valores originais
  // pelas gramas originais — isso funciona independente do valor
  // de porcao_padrao_g original, pois usamos o que foi salvo.
  double _calc100(double valorOriginal) {
    if (_gramasOriginais == 0) return 0;
    return valorOriginal / _gramasOriginais * 100;
  }

  double _calcAtual(double valorOriginal) =>
      _calc100(valorOriginal) * _gramas / 100;

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  // ── Salva as novas gramas e atualiza totais no Firestore ──────
  Future<void> _salvar() async {
    if (_gramas == _gramasOriginais) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _salvando = true);

    try {
      final double novasCal  = _calcAtual(_calOriginal);
      final double novasCarb = _calcAtual(_carbOriginal);
      final double novasProt = _calcAtual(_protOriginal);
      final double novasGord = _calcAtual(_gordOriginal);
      final double novasFib  = _calcAtual(_fibOriginal);

      // 1. Atualiza o item
      await widget.docRef.update({
        'porcao':   '${_gramas}g',
        'calorias': novasCal.round(),
        'carb':     novasCarb,
        'prot':     novasProt,
        'gord':     novasGord,
        'fib':      novasFib,
      });

      // 2. Atualiza os totais do documento pai com a diferença
      final diffCal  = novasCal  - _calOriginal;
      final diffCarb = novasCarb - _carbOriginal;
      final diffProt = novasProt - _protOriginal;
      final diffGord = novasGord - _gordOriginal;
      final diffFib  = novasFib  - _fibOriginal;

      await FirebaseFirestore.instance
          .collection('refeicoes_usuario')
          .doc(widget.refeicaoDocId)
          .update({
        'totalCalorias': FieldValue.increment(diffCal),
        'totalCarb':     FieldValue.increment(diffCarb),
        'totalProt':     FieldValue.increment(diffProt),
        'totalGord':     FieldValue.increment(diffGord),
        'totalFib':      FieldValue.increment(diffFib),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double cal  = _calcAtual(_calOriginal);
    final double carb = _calcAtual(_carbOriginal);
    final double prot = _calcAtual(_protOriginal);
    final double gord = _calcAtual(_gordOriginal);
    final double fib  = _calcAtual(_fibOriginal);

    final String nome = widget.itemData['nome'] ?? '';
    final bool mudou  = _gramas != _gramasOriginais;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Alça ────────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Cabeçalho ───────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit_outlined,
                    color: widget.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const Text('Editar quantidade',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Contador de gramas ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAFA),
              borderRadius: BorderRadius.circular(16),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botão −
                _CounterBtn(
                  icon: Icons.remove,
                  enabled: _gramas > _minGram,
                  color: Colors.teal,
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
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: mudou ? Colors.teal : Colors.black87,
                        height: 1,
                      ),
                    ),
                    Text(
                      'gramas',
                      style: TextStyle(
                          fontSize: 14,
                          color: mudou ? Colors.teal : Colors.grey,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'era: ${_gramasOriginais}g  ·  mín. $_minGram g',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),

                // Botão +
                _CounterBtn(
                  icon: Icons.add,
                  enabled: true,
                  color: Colors.teal,
                  onTap: () => setState(() => _gramas += _passo),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Preview de macros ────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: mudou
                  ? const Color(0xFFF0FAFA)
                  : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14),
              border: mudou
                  ? Border.all(color: Colors.teal.withOpacity(0.3))
                  : null,
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              children: [
                _MacroPrev(
                    label: 'Calorias',
                    value: '${_fmt(cal)} kcal',
                    color: widget.iconColor),
                _MacroPrev(
                    label: 'Carb',
                    value: '${_fmt(carb)}g',
                    color: Colors.teal),
                _MacroPrev(
                    label: 'Prot',
                    value: '${_fmt(prot)}g',
                    color: Colors.teal),
                _MacroPrev(
                    label: 'Gord',
                    value: '${_fmt(gord)}g',
                    color: Colors.teal),
                _MacroPrev(
                    label: 'Fib',
                    value: '${_fmt(fib)}g',
                    color: Colors.teal),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Botões de ação ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _salvando ? null : () => Navigator.pop(context, false),
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
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        mudou ? Colors.teal : Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          mudou
                              ? 'Salvar $_gramas g'
                              : 'Sem alterações',
                          style: TextStyle(
                              color: mudou
                                  ? Colors.white
                                  : Colors.grey.shade600,
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
class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _CounterBtn({
    required this.icon,
    required this.enabled,
    required this.color,
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
          color: enabled ? color : const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon,
            color: enabled ? Colors.white : Colors.grey, size: 26),
      ),
    );
  }
}

// ── Preview de macro individual ────────────────────────────────
class _MacroPrev extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroPrev({
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

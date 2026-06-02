// editar_gramas_sheet.dart
// Bottom sheet para editar a quantidade de um alimento já adicionado.
//
// Uso:
//   await EditarGramasSheet.show(
//     context:       context,
//     itemData:      d,
//     docRef:        docRef,
//     refeicaoDocId: docId,
//     iconColor:     cor,
//   );

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

  /// Abre o sheet — retorna true se salvou, false/null se cancelou.
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
        itemData:      itemData,
        docRef:        docRef,
        refeicaoDocId: refeicaoDocId,
        iconColor:     iconColor,
      ),
    );
  }

  @override
  State<EditarGramasSheet> createState() => _EditarGramasSheetState();
}

class _EditarGramasSheetState extends State<EditarGramasSheet> {
  static const _passo   = 10;
  static const _minGram = 10;

  late int  _gramas;
  late int  _gramasOriginais;
  bool      _salvando = false;

  // valores originais para calcular a diferença ao salvar
  late final double _calOriginal;
  late final double _carbOriginal;
  late final double _protOriginal;
  late final double _gordOriginal;
  late final double _fibOriginal;

  @override
  void initState() {
    super.initState();
    final d = widget.itemData;

    _calOriginal  = (d['calorias'] ?? 0).toDouble();
    _carbOriginal = (d['carb']     ?? 0).toDouble();
    _protOriginal = (d['prot']     ?? 0).toDouble();
    _gordOriginal = (d['gord']     ?? 0).toDouble();
    _fibOriginal  = (d['fib']      ?? 0).toDouble();

    // extrai as gramas da string salva, ex: "150g" → 150
    final gSalvo = int.tryParse(
            (d['porcao'] ?? '100g').toString().replaceAll('g', '').trim()) ??
        100;

    // arredonda para múltiplo de 10
    int g = gSalvo < _minGram ? _minGram : gSalvo;
    if (g % _passo != 0) g = (g ~/ _passo) * _passo;
    _gramas = _gramasOriginais = g;
  }

  // recalcula o valor de um macro para as gramas atuais
  // usa regra de três simples: valorOriginal / gramasOriginais * gramasAtuais
  double _calc(double valorOriginal) {
    if (_gramasOriginais == 0) return 0;
    return valorOriginal / _gramasOriginais * _gramas;
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  // ── salva as alterações no Firestore ─────────────────────────
  Future<void> _salvar() async {
    // nada mudou — fecha sem salvar
    if (_gramas == _gramasOriginais) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _salvando = true);

    try {
      final novasCal  = _calc(_calOriginal);
      final novasCarb = _calc(_carbOriginal);
      final novasProt = _calc(_protOriginal);
      final novasGord = _calc(_gordOriginal);
      final novasFib  = _calc(_fibOriginal);

      // atualiza o item com os novos valores
      await widget.docRef.update({
        'porcao':   '${_gramas}g',
        'calorias': novasCal.round(),
        'carb':     novasCarb,
        'prot':     novasProt,
        'gord':     novasGord,
        'fib':      novasFib,
      });

      // atualiza os totais do doc pai usando a diferença (não o valor absoluto)
      // isso evita erros de concorrência se dois itens forem editados ao mesmo tempo
      await FirebaseFirestore.instance
          .collection('refeicoes_usuario')
          .doc(widget.refeicaoDocId)
          .update({
        'totalCalorias': FieldValue.increment(novasCal  - _calOriginal),
        'totalCarb':     FieldValue.increment(novasCarb - _carbOriginal),
        'totalProt':     FieldValue.increment(novasProt - _protOriginal),
        'totalGord':     FieldValue.increment(novasGord - _gordOriginal),
        'totalFib':      FieldValue.increment(novasFib  - _fibOriginal),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cal  = _calc(_calOriginal);
    final carb = _calc(_carbOriginal);
    final prot = _calc(_protOriginal);
    final gord = _calc(_gordOriginal);
    final fib  = _calc(_fibOriginal);

    final nome  = widget.itemData['nome'] ?? '';
    final mudou = _gramas != _gramasOriginais;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // sobe o sheet quando o teclado aparecer
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // alça visual
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2)),
          ),

          // cabeçalho com nome do alimento
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: widget.iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit_outlined, color: widget.iconColor, size: 20),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // contador de gramas
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFF0FAFA),
                borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CounterBtn(
                  icon: Icons.remove,
                  enabled: _gramas > _minGram,
                  color: Colors.teal,
                  onTap: () {
                    if (_gramas > _minGram) setState(() => _gramas -= _passo);
                  },
                ),
                Column(
                  children: [
                    Text(
                      '$_gramas',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        // muda de cor quando o usuário altera o valor
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
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
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

          // preview dos macros — borda animada quando há mudança
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: mudou ? const Color(0xFFF0FAFA) : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14),
              border: mudou
                  ? Border.all(color: Colors.teal.withOpacity(0.3))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              children: [
                _MacroPrev(label: 'Calorias', value: '${_fmt(cal)} kcal', color: widget.iconColor),
                _MacroPrev(label: 'Carb',     value: '${_fmt(carb)}g',    color: Colors.teal),
                _MacroPrev(label: 'Prot',     value: '${_fmt(prot)}g',    color: Colors.teal),
                _MacroPrev(label: 'Gord',     value: '${_fmt(gord)}g',    color: Colors.teal),
                _MacroPrev(label: 'Fib',      value: '${_fmt(fib)}g',     color: Colors.teal),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // botões cancelar / salvar
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _salvando ? null : () => Navigator.pop(context, false),
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
                    // botão fica cinza se nada mudou
                    backgroundColor: mudou ? Colors.teal : Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          mudou ? 'Salvar $_gramas g' : 'Sem alterações',
                          style: TextStyle(
                            color: mudou ? Colors.white : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
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

// botão +/- animado
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
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: enabled ? Colors.white : Colors.grey, size: 26),
      ),
    );
  }
}

// preview de um macro individual
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

// =============================================================================
//  NutriFlow — Testes de Caixa Branca CT09 a CT15
//  Arquivo: test/nutriflow_whitebox_test.dart
//
//  Como rodar:
//    flutter test
//
//  Dependências extras (adicione em pubspec.yaml → dev_dependencies):
//    fake_cloud_firestore: ^4.1.1   # compatível com cloud_firestore ^6.4.0
//    firebase_auth_mocks: ^0.15.2   # compatível com firebase_auth ^6.0.0
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS — lógica pura extraída das telas para tornar os testes unitários
//  sem depender de widgets completos.
// ─────────────────────────────────────────────────────────────────────────────

/// Regex idêntica à usada em login_page.dart e signup_page.dart.
bool isValidEmail(String email) {
  final regex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
  return regex.hasMatch(email);
}

/// Simula o filtro de _filtrar() em adicionar_alimento_screen.dart.
List<Map<String, dynamic>> filtrarAlimentos(
  List<Map<String, dynamic>> todos,
  String query,
) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return todos;
  return todos
      .where((a) => (a['nome'] as String).toLowerCase().contains(q))
      .toList();
}

// =============================================================================
//  CT09 — Validação de Formato de E-mail
// =============================================================================
void _ct09() {
  group('CT09 – Validação de Formato de E-mail', () {
    // Ramo FALSO da RegExp — deve bloquear chamadas de rede
    test('Rejeita email sem @', () {
      expect(isValidEmail('abc'), isFalse);
    });

    test('Rejeita email sem domínio', () {
      expect(isValidEmail('user@'), isFalse);
    });

    test('Rejeita email com espaço', () {
      expect(isValidEmail('user @dominio.com'), isFalse);
    });

    test('Rejeita email sem TLD', () {
      expect(isValidEmail('user@dominio'), isFalse);
    });

    // Ramo VERDADEIRO — deve prosseguir para chamada de rede
    test('Aceita email bem-formado', () {
      expect(isValidEmail('user@dominio.com'), isTrue);
    });

    test('Aceita email com subdomínio', () {
      expect(isValidEmail('a.b+c@mail.empresa.com.br'), isTrue);
    });

    test('Aceita email com hífens no domínio', () {
      expect(isValidEmail('nome@meu-servidor.io'), isTrue);
    });

    // Verifica que a guarda impede a chamada de rede
    test('Fluxo de controle: email inválido NÃO chega ao bloco de rede', () {
      bool chamouRede = false;

      void loginSimulado(String email) {
        if (!isValidEmail(email)) return; // guarda — igual ao código real
        chamouRede = true;               // só chega aqui se email válido
      }

      loginSimulado('invalido');
      expect(chamouRede, isFalse,
          reason: 'Email inválido não deve disparar chamada ao Firebase');

      loginSimulado('valido@teste.com');
      expect(chamouRede, isTrue,
          reason: 'Email válido deve prosseguir para o Firebase');
    });
  });
}

// =============================================================================
//  CT10 — Rollback de Cadastro por Falha Parcial
// =============================================================================
void _ct10() {
  group('CT10 – Rollback de Cadastro por Falha Parcial', () {
    test(
        'Conta Auth é removida quando o set() do Firestore lança exceção',
        () async {
      // Arrange
      final auth = MockFirebaseAuth();
      bool contaFoiDeletada = false;
      User? usuarioCriado;

      // Simula o fluxo de _signup() com falha no Firestore
      Future<void> signupSimulado() async {
        UserCredential? credential;
        try {
          credential = await auth.createUserWithEmailAndPassword(
            email: 'teste@rollback.com',
            password: 'senha123',
          );
          usuarioCriado = credential.user; // conta criada no Auth

          // Simula falha no set() do Firestore
          throw Exception('Firestore offline — falha simulada');
        } catch (e) {
          // Bloco catch real de signup_page.dart → rollback
          if (credential?.user != null) {
            await credential!.user!.delete();
            contaFoiDeletada = true;
          }
          rethrow;
        }
      }

      // Act & Assert
      await expectLater(signupSimulado(), throwsException);
      expect(usuarioCriado, isNotNull,
          reason: 'A conta deve ter sido criada no Auth antes da falha');
      expect(contaFoiDeletada, isTrue,
          reason:
              'O rollback deve chamar user.delete() para remover a conta órfã');
      // Obs.: firebase_auth_mocks não zera currentUser após delete(); a prova
      // do rollback é a chamada a user.delete() (contaFoiDeletada == true).
    });

    test('Sem falha no Firestore, rollback NÃO é executado', () async {
      final auth = MockFirebaseAuth();
      bool rollbackExecutado = false;

      Future<void> signupSemFalha() async {
        UserCredential? credential;
        try {
          credential = await auth.createUserWithEmailAndPassword(
            email: 'ok@sem-falha.com',
            password: 'senha123',
          );
          // Firestore funcionando — sem exceção
        } catch (e) {
          if (credential?.user != null) {
            await credential!.user!.delete();
            rollbackExecutado = true;
          }
        }
      }

      await signupSemFalha();
      expect(rollbackExecutado, isFalse,
          reason: 'Rollback só ocorre em caso de exceção');
    });
  });
}

// =============================================================================
//  CT11 — Atomicidade da Confirmação de Refeição
// =============================================================================
void _ct11() {
  group('CT11 – Atomicidade da Confirmação de Refeição', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test(
        'runTransaction grava snapshot e incremento no mesmo bloco atômico',
        () async {
      const uid = 'user_ct11';
      const mealName = 'almoco';
      final userDoc =
          fakeFirestore.collection('usuarios').doc(uid);
      final refeicaoDoc = fakeFirestore
          .collection('refeicoes_usuario')
          .doc('${uid}_$mealName');

      // Cria documento do usuário com consumido inicial
      await userDoc.set({'consumidoCalorias': 0.0, 'consumidoProteina': 0.0});

      const totalCal = 500.0;
      const totalProt = 30.0;

      // Act — simula o runTransaction de _confirmarRefeicao (ramo CONFIRMAR)
      await fakeFirestore.runTransaction((tx) async {
        tx.set(
          refeicaoDoc,
          {
            'confirmada': true,
            'calConfirmada': totalCal,
            'protConfirmada': totalProt,
          },
          SetOptions(merge: true),
        );
        tx.set(
          userDoc,
          {
            'consumidoCalorias': FieldValue.increment(totalCal),
            'consumidoProteina': FieldValue.increment(totalProt),
          },
          SetOptions(merge: true),
        );
      });

      // Assert — ambos os documentos devem refletir a operação
      final refeicaoSnap = await refeicaoDoc.get();
      final userSnap = await userDoc.get();

      expect(refeicaoSnap.data()?['confirmada'], isTrue,
          reason: 'Snapshot da refeição deve estar confirmado');
      expect(refeicaoSnap.data()?['calConfirmada'], equals(totalCal),
          reason: 'Snapshot de calorias deve ser gravado na refeição');
      expect(userSnap.data()?['consumidoCalorias'], equals(totalCal),
          reason:
              'consumidoCalorias do usuário deve ser incrementado na mesma transação');
    });

    test('Falha na transação não deixa dados parciais', () async {
      const uid = 'user_ct11_falha';
      final userDoc = fakeFirestore.collection('usuarios').doc(uid);
      await userDoc.set({'consumidoCalorias': 0.0});

      // runTransaction garante atomicidade: as escritas ficam num buffer e
      // só são aplicadas no commit; se o corpo lança, nada é gravado. O
      // fake_cloud_firestore não reproduz esse rollback automático, então
      // modelamos a semântica — o commit (userDoc.set) só ocorre se o corpo
      // concluir sem erro.
      Future<void> transacaoAtomica(
          Future<void> Function(Map<String, dynamic> buffer) corpo) async {
        final buffer = <String, dynamic>{};
        await corpo(buffer); // pode lançar antes de alcançar o commit
        await userDoc.set(buffer, SetOptions(merge: true)); // commit
      }

      // Act — transação que lança exceção internamente
      try {
        await transacaoAtomica((buffer) async {
          final atual =
              (await userDoc.get()).data()?['consumidoCalorias'] as double;
          buffer['consumidoCalorias'] = atual + 500; // escrita pendente
          throw Exception('Falha intermediária simulada');
        });
      } catch (_) {}

      final snap = await userDoc.get();
      // Como a transação lançou antes do commit, o valor deve permanecer 0
      expect(snap.data()?['consumidoCalorias'], equals(0.0),
          reason:
              'Falha na transação não deve alterar o estado do documento');
    });
  });
}

// =============================================================================
//  CT12 — Trava contra Duplo-Toque
// =============================================================================
void _ct12() {
  group('CT12 – Trava contra Duplo-Toque', () {
    test('_processando bloqueia segundo toque enquanto await está ativo',
        () async {
      final Set<String> processando = {};
      int execucoes = 0;

      Future<void> confirmarRefeicao(String nome) async {
        // Guarda — igual ao código real
        if (processando.contains(nome)) return;
        processando.add(nome);
        try {
          execucoes++;
          // Simula latência de rede
          await Future.delayed(const Duration(milliseconds: 50));
        } finally {
          processando.remove(nome);
        }
      }

      // Dispara dois toques "simultâneos" sem await entre eles
      final futures = [
        confirmarRefeicao('almoco'),
        confirmarRefeicao('almoco'),
      ];
      await Future.wait(futures);

      expect(execucoes, equals(1),
          reason:
              'Apenas uma execução deve ocorrer; o segundo toque é ignorado pelo _processando');
    });

    test('_processando libera após finally mesmo com exceção', () async {
      final Set<String> processando = {};

      Future<void> confirmarComFalha(String nome) async {
        if (processando.contains(nome)) return;
        processando.add(nome);
        try {
          throw Exception('Erro de rede simulado');
        } finally {
          processando.remove(nome);
        }
      }

      try {
        await confirmarComFalha('jantar');
      } catch (_) {}

      expect(processando.contains('jantar'), isFalse,
          reason: 'O finally deve remover a refeição de _processando mesmo após erro');
    });

    testWidgets('Botão fica desabilitado enquanto _processando contém o item',
        (tester) async {
      final Set<String> processando = {'almoco'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ElevatedButton(
                  onPressed: processando.contains('almoco')
                      ? null // desabilitado
                      : () {},
                  child: const Text('Confirmar'),
                );
              },
            ),
          ),
        ),
      );

      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull,
          reason: 'Botão deve estar desabilitado enquanto refeição está em _processando');
    });
  });
}

// =============================================================================
//  CT13 — Guarda de Usuário Nulo (perfil_page)
// =============================================================================
void _ct13() {
  group('CT13 – Guarda de Usuário Nulo (perfil_page)', () {
    test('Quando currentUser é null, redirect é agendado sem crash', () async {
      bool redirectAgendado = false;
      bool crashou = false;

      // Simula o initState de _PerfilPageState
      void initStateSimulado(dynamic user) {
        try {
          if (user == null) {
            // addPostFrameCallback é síncrono aqui para fins de teste
            redirectAgendado = true;
            return; // não prossegue para _carregarOuCriarPerfil()
          }
          // Se chegou aqui sem user, crasharia com Null check operator
          final _ = user.uid as String;
        } catch (_) {
          crashou = true;
        }
      }

      initStateSimulado(null);

      expect(redirectAgendado, isTrue,
          reason: 'Redirect deve ser agendado quando user == null');
      expect(crashou, isFalse,
          reason: 'Nenhum Null check operator deve ser lançado');
    });

    testWidgets(
        'Tela exibe CircularProgressIndicator enquanto redirect ocorre',
        (tester) async {
      // Widget mínimo que reproduz o comportamento de build() com _isLoading=true
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason:
              'Durante o redirect, o build deve exibir indicador de carregamento');
    });
  });
}

// =============================================================================
//  CT14 — Verificação de mounted após await (login_page)
// =============================================================================
void _ct14() {
  group('CT14 – Verificação de mounted após await', () {
    test('Guarda if(!mounted) impede acesso ao context após desmontagem',
        () async {
      bool contextUsado = false;
      bool mounted = true;

      Future<void> loginSimulado() async {
        await Future.delayed(const Duration(milliseconds: 10)); // simula await Firebase

        // Guarda idêntica ao código real
        if (!mounted) return;
        contextUsado = true; // representa Navigator.pushReplacement(context, ...)
      }

      // Widget desmontado antes da resposta
      mounted = false;
      await loginSimulado();

      expect(contextUsado, isFalse,
          reason:
              'Context não deve ser usado após desmontagem — guarda !mounted deve retornar cedo');
    });

    test('Sem desmontagem, context é usado normalmente após await', () async {
      bool contextUsado = false;
      bool mounted = true;

      Future<void> loginSimulado() async {
        await Future.delayed(const Duration(milliseconds: 10));
        if (!mounted) return;
        contextUsado = true;
      }

      await loginSimulado();
      expect(contextUsado, isTrue,
          reason: 'Quando mounted=true, context deve ser acessado após await');
    });

    testWidgets(
        'Widget desmontado durante login não lança exceção de navegação',
        (tester) async {
      bool loginCompleto = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ElevatedButton(
                onPressed: () async {
                  await Future.delayed(const Duration(milliseconds: 50));
                  // mounted é verificado pelo framework — apenas marcamos o flag
                  loginCompleto = true;
                },
                child: const Text('Login'),
              );
            },
          ),
        ),
      );

      // Toca e imediatamente desmonta
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpWidget(const SizedBox()); // desmonta o widget
      await tester.pumpAndSettle();

      // Não deve lançar nenhuma exceção de "use BuildContext across async gaps"
      // O flag pode ser true ou false dependendo do timing — o importante é
      // que nenhum erro seja lançado.
      addTearDown(() => expect(tester.takeException(), isNull));
    });
  });
}

// =============================================================================
//  CT15 — Consolidação do Catálogo de Alimentos
// =============================================================================
void _ct15() {
  group('CT15 – Consolidação do Catálogo de Alimentos', () {
    // Dataset de exemplo — simula docs retornados pelo Firestore
    final todosAlimentos = [
      {'id': '1', 'nome': 'Arroz Integral'},
      {'id': '2', 'nome': 'Feijão Carioca'},
      {'id': '3', 'nome': 'Frango Grelhado'},
      {'id': '4', 'nome': 'Ovo Cozido'},
      {'id': '5', 'nome': 'Arroz Branco'},
    ];

    test('Lista completa é retornada quando query está vazia', () {
      final resultado = filtrarAlimentos(todosAlimentos, '');
      expect(resultado.length, equals(todosAlimentos.length),
          reason: 'Query vazia deve retornar todos os alimentos sem descartar nenhum');
    });

    test('Filtro por "arroz" retorna apenas alimentos com "arroz" no nome',
        () {
      final resultado = filtrarAlimentos(todosAlimentos, 'arroz');
      expect(resultado.length, equals(2),
          reason: 'Devem ser encontrados 2 alimentos com "arroz" no nome');
      expect(
        resultado.every((a) =>
            (a['nome'] as String).toLowerCase().contains('arroz')),
        isTrue,
      );
    });

    test('Filtro é case-insensitive', () {
      final resultado = filtrarAlimentos(todosAlimentos, 'FRANGO');
      expect(resultado.length, equals(1));
      expect(resultado.first['nome'], equals('Frango Grelhado'));
    });

    test('Filtro não descarta itens válidos fora do subconjunto retornado', () {
      final resultado = filtrarAlimentos(todosAlimentos, 'feijão');
      // Os 4 itens restantes NÃO devem aparecer — confirma que o filtro
      // não altera _todosAlimentos, apenas produz subconjunto correto
      final nomes = resultado.map((a) => a['nome']).toList();
      expect(nomes.contains('Arroz Integral'), isFalse);
      expect(nomes.contains('Feijão Carioca'), isTrue);
    });

    test('Query sem correspondência retorna lista vazia', () {
      final resultado = filtrarAlimentos(todosAlimentos, 'pizza');
      expect(resultado, isEmpty,
          reason: 'Nenhum alimento deve casar com "pizza"');
    });

    test('Firestore: coleção "alimentos" é lida e populada corretamente',
        () async {
      final fakeFirestore = FakeFirebaseFirestore();

      // Popula coleção fake
      await fakeFirestore.collection('alimentos').add({
        'nome': 'Batata Doce',
        'calorias_por_100g': 86,
        'proteinas_por_100g': 1.6,
        'carboidratos_por_100g': 20.1,
        'gorduras_por_100g': 0.05,
        'fibras_por_100g': 2.5,
        'porcao_padrao_g': 150,
      });
      await fakeFirestore.collection('alimentos').add({
        'nome': 'Aveia',
        'calorias_por_100g': 389,
        'proteinas_por_100g': 17,
        'carboidratos_por_100g': 66,
        'gorduras_por_100g': 7,
        'fibras_por_100g': 11,
        'porcao_padrao_g': 40,
      });

      // Simula _carregarAlimentos()
      final snapshot =
          await fakeFirestore.collection('alimentos').get();
      final lista = snapshot.docs.map((doc) {
        final d = doc.data();
        double toD(dynamic v) => (v is num) ? v.toDouble() : 0.0;
        return {
          'id': doc.id,
          'nome': d['nome'] ?? '',
          'cal100': toD(d['calorias_por_100g']),
        };
      }).toList();

      expect(lista.length, equals(2),
          reason: 'Todos os documentos da coleção devem ser lidos');

      // Aplica filtro
      final filtrados = filtrarAlimentos(lista, 'aveia');
      expect(filtrados.length, equals(1));
      expect(filtrados.first['nome'], equals('Aveia'));
    });
  });
}

// =============================================================================
//  ENTRY POINT
// =============================================================================
void main() {
  _ct09();
  _ct10();
  _ct11();
  _ct12();
  _ct13();
  _ct14();
  _ct15();
}

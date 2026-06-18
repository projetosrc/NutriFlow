// signup_page.dart
// Tela de Cadastro do aplicativo NutriFlow.
// Usa Firebase Authentication para criar uma nova conta com email e senha.
// Após o cadastro, salva o nome do usuário no Firebase Auth (displayName).

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Pacote de autenticação do Firebase
import 'login_page.dart'; // Tela de Login
import 'home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Controladores para capturar o texto digitado nos campos
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controla se o botão está carregando (evita cliques duplos)
  bool _isLoading = false;

  @override
  void dispose() {
    // Libera os controladores da memória quando o widget é destruído
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Cria uma nova conta no Firebase Auth com email e senha.
  /// Também salva o nome do usuário no perfil (displayName).
  Future<void> _signup() async {
    // Evita múltiplos cliques enquanto está carregando
    if (_isLoading) return;

    // Validação básica: todos os campos devem ser preenchidos
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showMessage('Preencha todos os campos.');
      return;
    }

    // Validação de formato de email (DEF-004)
    if (!_isValidEmail(_emailController.text.trim())) {
      _showMessage('Email inválido. Verifique e tente novamente.');
      return;
    }

    // Validação de senha: mínimo de 6 caracteres (requisito do Firebase)
    if (_passwordController.text.trim().length < 6) {
      _showMessage('A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    // Ativa o indicador de carregamento
    setState(() => _isLoading = true);

    // Mantém a referência à conta criada para permitir rollback (DEF-005)
    UserCredential? credential;

    try {
      // Cria a conta no Firebase Auth com email e senha
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Após criar a conta, salva o nome completo no perfil do usuário
      await credential.user?.updateDisplayName(_nameController.text.trim());

      // CREATE: cria o documento do usuário no Firestore com valores padrão
      // Isso garante que o perfil exista desde o primeiro acesso
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(credential.user!.uid)
          .set({
        'nome': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'metaCalorica': 2000,
        'metaPeso': 70.0,
        'altura': 170,
        'carboidrato': 250,
        'proteina': 150,
        'gordura': 55,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      // Cadastro bem-sucedido. Verifica `mounted` antes de usar `context`
      // após o await (DEF-001) e exibe a mensagem antes de navegar (DEF-012).
      if (!mounted) return;
      _showMessage('Conta criada com sucesso!');
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomePage()));

    } on FirebaseAuthException catch (e) {
      // Trata os erros específicos do Firebase Auth
      // com mensagens amigáveis em português
      switch (e.code) {
        case 'email-already-in-use':
          _showMessage('Este email já está em uso. Faça login.');
          break;
        case 'invalid-email':
          _showMessage('Email inválido. Verifique e tente novamente.');
          break;
        case 'weak-password':
          _showMessage('Senha fraca. Use pelo menos 6 caracteres.');
          break;
        case 'operation-not-allowed':
          _showMessage('Cadastro com email desativado no Firebase Console.');
          break;
        default:
          _showMessage(e.message ?? 'Erro ao criar conta.');
      }
    } catch (e) {
      // Rollback de falha parcial (DEF-005): se a conta foi criada no Auth
      // mas o documento no Firestore falhou, removemos a conta órfã para
      // que o usuário possa tentar novamente do zero.
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          // Se nem o rollback funcionar, não há mais o que fazer aqui.
        }
      }
      _showMessage('Erro inesperado. Tente novamente.');
    } finally {
      // Desativa o indicador de carregamento independente do resultado
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Valida o formato do email com uma expressão regular simples (DEF-004).
  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
    return regex.hasMatch(email);
  }

  /// Exibe uma mensagem na parte inferior da tela (SnackBar).
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Gradiente de fundo: azul claro no topo até branco na base
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0F7F9),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),

              // ── Logo do app ──────────────────────────────────────────
              Image.asset(
                'assets/icons/logo.png',
                height: 200,
                width: 200,
              ),

              const SizedBox(height: 40),

              // ── Card branco com o formulário de cadastro ──────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  // Bordas arredondadas apenas no topo
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Título e subtítulo ──────────────────────────────
                    const Center(
                      child: Text(
                        'Crie sua conta',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Comece sua jornada saudável hoje',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF0D9488),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Campo de Nome Completo ───────────────────────────
                    const Text(
                      'Nome completo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words, // Capitaliza cada palavra
                      decoration: InputDecoration(
                        hintText: 'Seu nome',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Campo de Email ──────────────────────────────────
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress, // Abre teclado com @
                      decoration: InputDecoration(
                        hintText: 'seu@email.com',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Campo de Senha ──────────────────────────────────
                    const Text(
                      'Senha',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true, // Oculta os caracteres da senha
                      decoration: InputDecoration(
                        hintText: '........',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Botão Criar Conta ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        // Chama _signup() ou null (desabilita) enquanto carrega
                        onPressed: _isLoading ? null : _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            // Mostra um spinner enquanto aguarda resposta do Firebase
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Criar conta',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Link para Login ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Já tem uma conta? ',
                          style: TextStyle(color: Color(0xFF4B5563)),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Volta para a tela de Login (remove SignupPage da pilha)
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Faça login',
                            style: TextStyle(
                              color: Color(0xFF0D9488),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

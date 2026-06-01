// login_page.dart
// Tela de Login do aplicativo NutriFlow.
// Usa Firebase Authentication para autenticar o usuário com email e senha.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'signup_page.dart'; // Tela de Cadastro
import 'home_page.dart'; // Importa a HomePage

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para capturar o texto digitado nos campos
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controla se o botão está carregando (evita cliques duplos)
  bool _isLoading = false;

  @override
  void dispose() {
    // Libera os controladores da memória quando o widget é destruído
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Realiza o login com email e senha usando Firebase Auth.
  /// Exibe mensagens de erro amigáveis em caso de falha.
  Future<void> _login() async {
    // Evita múltiplos cliques enquanto está carregando
    if (_isLoading) return;

    // Validação básica: campos não podem estar vazios
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showMessage('Preencha todos os campos.');
      return;
    }

    // Ativa o indicador de carregamento
    setState(() => _isLoading = true);

    try {
      // Tenta fazer login no Firebase Auth com email e senha
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Login bem-sucedido — navegar para a tela principal aqui
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      _showMessage('Login realizado com sucesso!');

    } on FirebaseAuthException catch (e) {
      // Trata os erros específicos do Firebase Auth
      // com mensagens amigáveis em português
      switch (e.code) {
        case 'user-not-found':
          _showMessage('Nenhuma conta encontrada com este email.');
          break;
        case 'wrong-password':
          _showMessage('Senha incorreta. Tente novamente.');
          break;
        case 'invalid-email':
          _showMessage('Email inválido. Verifique e tente novamente.');
          break;
        case 'user-disabled':
          _showMessage('Esta conta foi desativada.');
          break;
        case 'too-many-requests':
          _showMessage('Muitas tentativas. Tente novamente mais tarde.');
          break;
        default:
          _showMessage(e.message ?? 'Erro ao fazer login.');
      }
    } catch (e) {
      // Captura erros genéricos inesperados
      _showMessage('Erro inesperado. Tente novamente.');
    } finally {
      // Desativa o indicador de carregamento independente do resultado
      if (mounted) setState(() => _isLoading = false);
    }
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

              // ── Card branco com o formulário de login ─────────────────
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
                        'Bem-vindo de volta!',
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
                        'Entre para continuar sua jornada saudável',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF0D9488),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

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
                    const SizedBox(height: 16),

                    // ── Link "Esqueceu a senha?" ─────────────────────────
                    TextButton(
                      onPressed: () {
                        // TODO: implementar recuperação de senha
                        // Exemplo: FirebaseAuth.instance.sendPasswordResetEmail(email: ...)
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        'Esqueceu a senha?',
                        style: TextStyle(
                          color: Color(0xFF0D9488),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Botão Entrar ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        // Chama _login() ou null (desabilita) enquanto carrega
                        onPressed: _isLoading ? null : _login,
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
                                'Entrar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Link para Cadastro ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Não tem uma conta? ',
                          style: TextStyle(color: Color(0xFF4B5563)),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Navega para a tela de cadastro
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Cadastre-se',
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

// signup_page.dart
// Tela de Cadastro do NutriFlow.
// Cria conta no Firebase Auth e já salva os dados do usuário no Firestore.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'refeicoes_screen.dart';


class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_isLoading) return;

    // todos os campos são obrigatórios
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showMessage('Preencha todos os campos.');
      return;
    }

    // Firebase exige no mínimo 6 caracteres
    if (_passwordController.text.trim().length < 6) {
      _showMessage('A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // cria a conta no Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // salva o nome no perfil do usuário (aparece na tela de perfil)
      await credential.user?.updateDisplayName(_nameController.text.trim());

      // cria o documento do usuário no Firestore com valores padrão
      // isso garante que o perfil já exista na primeira vez que abrir
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(credential.user!.uid)
          .set({
        'nome':        _nameController.text.trim(),
        'email':       _emailController.text.trim(),
      });

      // cadastro OK — vai direto pra home
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RefeicoeScreen()),
          (route) => false,
        );
      }
     

    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use'  => 'Este email já está em uso. Faça login.',
        'invalid-email'         => 'Email inválido. Verifique e tente novamente.',
        'weak-password'         => 'Senha fraca. Use pelo menos 6 caracteres.',
        'operation-not-allowed' => 'Cadastro com email desativado no Firebase Console.',
        _                       => e.message ?? 'Erro ao criar conta.',
      };
      _showMessage(msg);
    } catch (_) {
      _showMessage('Erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Color(0xFFE0F7F9), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),

              // logo
              Image.asset('assets/icons/logo.png', height: 200, width: 200),

              const SizedBox(height: 40),

              // card branco com formulário
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft:  Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

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

                    _buildLabel('Nome completo'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Seu nome',
                      capitalize: TextCapitalization.words,
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('Email'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'seu@email.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('Senha'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordController,
                      hint: '........',
                      obscure: true,
                    ),
                    const SizedBox(height: 32),

                    // botão criar conta
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24, width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
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

                    // link para voltar ao login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Já tem uma conta? ',
                          style: TextStyle(color: Color(0xFF4B5563)),
                        ),
                        GestureDetector(
                          // pop volta pra LoginPage que já está na pilha
                          onTap: () => Navigator.pop(context),
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

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Color(0xFF374151),
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalize = TextCapitalization.none,
    bool obscure = false,
  }) =>
      TextField(
        controller:           controller,
        keyboardType:         keyboardType,
        textCapitalization:   capitalize,
        obscureText:          obscure,
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          filled:    true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );
}

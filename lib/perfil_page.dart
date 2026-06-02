// perfil_page.dart
// Tela de Perfil — NutriFlow
// Exibe nome e email do usuário com opções de sair e excluir conta.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  // pega o usuário do Firebase Auth — não precisa ir ao Firestore
  // só para exibir nome e email
  final _user = FirebaseAuth.instance.currentUser;

  // ── LOGOUT ───────────────────────────────────────────────────
  // signOut encerra a sessão no Firebase Auth.
  // pushAndRemoveUntil com (route) => false limpa toda a pilha
  // de navegação para o usuário não conseguir voltar com o back.
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

  // ── EXCLUIR CONTA ─────────────────────────────────────────────
  // 1. pede confirmação
  // 2. deleta o documento do usuário no Firestore
  // 3. deleta a conta no Firebase Auth
  //
  // Obs: se o login foi há muito tempo, o Firebase pode pedir
  // reautenticação (requires-recent-login)
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
      // deleta o documento do usuário no Firestore primeiro
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_user!.uid)
          .delete();

      // depois deleta a conta do Firebase Auth
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

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // nome e email vêm do Firebase Auth — salvos no cadastro
    final nome  = _user?.displayName ?? 'Usuário';
    final email = _user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Perfil',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // card com avatar, nome e email
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      // avatar com inicial — poderia virar foto no futuro
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE6F7F5),
                          border: Border.all(color: Colors.teal, width: 2.5),
                        ),
                        child: const Icon(Icons.person, color: Colors.teal, size: 44),
                      ),
                      const SizedBox(height: 14),
                      Text(nome,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // botão sair
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon:  const Icon(Icons.logout, color: Colors.teal),
                label: const Text(
                  'Sair da conta',
                  style: TextStyle(
                      color: Colors.teal, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.teal),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // botão excluir conta (vermelho para dar o sinal de perigo)
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                onPressed: _excluirConta,
                icon:  const Icon(Icons.delete_forever_outlined, color: Colors.red),
                label: const Text(
                  'Excluir minha conta',
                  style: TextStyle(
                      color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600),
                ),
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // índice 1 = perfil
        selectedItemColor:   Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Dieta'),
          BottomNavigationBarItem(icon: Icon(Icons.person),           label: 'Perfil'),
        ],
        onTap: (index) {
          if (index == 0) Navigator.pop(context);
        },
      ),
    );
  }
}

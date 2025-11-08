import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/roles.dart';
import '../../../data/providers.dart';
import '../../../core/config/dev_flags.dart';
import '../../../data/models/app_user.dart';

/// Écran d'aiguillage en fonction de l'état d'auth et du rôle.
class RoleRedirectorScreen extends ConsumerWidget {
  const RoleRedirectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final appUser = ref.watch(currentUserDocProvider);
    // Plus de Firebase : on route selon l'état d'auth et le rôle utilisateur.

    // 2) Si non connecté => vers login
    if (auth.asData != null && auth.value == null) {
      // petit délai pour éviter setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.login);
      });
    }

    // 3) Si connecté mais user doc pas encore dispo => loader
    if (auth.value != null && appUser.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 4) Si connecté mais user doc absent => compléter le profil (choix rôle)
    if (auth.value != null && appUser.value == null) {
      return _CompleteProfileScreen();
    }

    // 5) Si connecté + user doc présent => route selon rôle
    final role = appUser.value?.role;
    if (role == UserRoles.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.classes);
      });
    } else if (role == UserRoles.teacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.classes);
      });
    } else if (role == UserRoles.student) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.studentSchedule);
      });
    }

    // Écran d'attente/landing minimal avec actions manuelles
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion Présence')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Bienvenue. Connexion/Inscription ou redirection auto."),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Connexion'),
                  ),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.signup),
                    child: const Text('Inscription'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompleteProfileScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<_CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _role = UserRoles.student;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = ref.read(authStateProvider).value!;
      final profile = AppUser(
        id: user.uid,
        role: _role,
        name: _nameCtrl.text.trim().isEmpty ? (user.email?.split('@').first ?? '') : _nameCtrl.text.trim(),
        email: user.email ?? '',
      );
      await ref.read(usersRepositoryProvider).setUser(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profil complété.'),
      ));
      context.go(AppRoutes.root);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Compléter le profil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Compte: ${authUser?.email}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Étudiant'),
                          value: UserRoles.student,
                          groupValue: _role,
                          onChanged: _saving ? null : (v) => setState(() => _role = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Enseignant'),
                          value: UserRoles.teacher,
                          groupValue: _role,
                          onChanged: _saving ? null : (v) => setState(() => _role = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Admin'),
                          value: UserRoles.admin,
                          groupValue: _role,
                          onChanged: _saving ? null : (v) => setState(() => _role = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

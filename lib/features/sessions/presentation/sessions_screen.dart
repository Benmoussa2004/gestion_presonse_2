import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/roles.dart';
import '../../../core/widgets/role_badge.dart';
import '../../../core/widgets/admin_drawer.dart';
import '../../../mvc/providers.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/providers.dart';
import 'session_editor_dialog.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserDocProvider).value;
    final bool isAdmin = me?.role == UserRoles.admin;
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final classesCtrl = ref.watch(classesControllerProvider);
    final sessionsCtrl = ref.watch(sessionsControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final classesStream = isAdmin
        ? classesCtrl.watchAll()
        : classesCtrl.watchForTeacher(uid);

    return StreamBuilder<List<ClassModel>>(
      stream: classesStream,
      builder: (context, classesSnap) {
        final classes = classesSnap.data ?? const <ClassModel>[];
        if (classes.isNotEmpty && (_selectedClassId == null ||
            !classes.any((c) => c.id == _selectedClassId))) {
          _selectedClassId = classes.first.id;
        }
        final selectedId = _selectedClassId;

        return Scaffold(
          backgroundColor: colorScheme.background,
          appBar: AppBar(
            title: Text(
              'Gestion des Séances',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onBackground,
              ),
            ),
            backgroundColor: colorScheme.surface,
            elevation: 0,
            actions: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: RoleBadge(),
              ),
              if (!isAdmin)
                IconButton(
                  tooltip: 'Déconnexion',
                  icon: Icon(Icons.logout, color: colorScheme.onSurface),
                  onPressed: () async {
                    await ref.read(authControllerProvider).signOut();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                ),
            ],
          ),
          drawer: isAdmin ? const AdminDrawer() : null,
          body: classesSnap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : classes.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 64,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune classe disponible',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAdmin
                      ? 'Créez d\'abord une classe pour ajouter des séances'
                      : 'Aucune classe ne vous est assignée',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
              : Column(
            children: [
              // Sélecteur de classe
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedId,
                  items: [
                    for (final c in classes)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.name,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedClassId = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'Sélectionnez une classe',
                    labelStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.class_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<SessionModel>>(
                  stream: sessionsCtrl.watchForClass(selectedId!),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final sessions = snap.data ?? [];

                    if (sessions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 64,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune séance programmée',
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Créez une séance pour commencer',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.separated(
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final s = sessions[i];
                          return _SessionCard(
                            session: s,
                            classId: selectedId!,
                            isAdmin: isAdmin,
                            sessionsCtrl: sessionsCtrl,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                            ref: ref, // Passer ref au _SessionCard
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: classes.isEmpty
              ? null
              : FloatingActionButton(
            onPressed: () => showSessionEditorDialog(context, ref, classId: selectedId!),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.classId,
    required this.isAdmin,
    required this.sessionsCtrl,
    required this.colorScheme,
    required this.textTheme,
    required this.ref, // Recevoir ref en paramètre
  });

  final SessionModel session;
  final String classId;
  final bool isAdmin;
  final dynamic sessionsCtrl;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final WidgetRef ref; // Ajouter ref comme paramètre

  Future<void> _deleteSession(BuildContext context, SessionModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Supprimer la séance ?',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          'La séance "${s.name}" du ${s.startAt.day}/${s.startAt.month}/${s.startAt.year} sera définitivement supprimée.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await sessionsCtrl.remove(s.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec horaires
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_outlined,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name.isNotEmpty ? session.name : 'Séance sans nom',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.startAt.day}/${session.startAt.month}/${session.startAt.year} ${session.startAt.hour}:${session.startAt.minute.toString().padLeft(2, '0')} → ${session.endAt.hour}:${session.endAt.minute.toString().padLeft(2, '0')}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  IconButton(
                    tooltip: 'Modifier',
                    icon: Icon(
                      Icons.edit_outlined,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    onPressed: () => showSessionEditorDialog(
                        context,
                        ref, // Utiliser ref directement
                        classId: classId,
                        existing: session
                    ),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: Icon(
                      Icons.delete_outline,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    onPressed: () => _deleteSession(context, session),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Code QR et informations
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.qr_code_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code de présence',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.code,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copier le code',
                    icon: Icon(
                      Icons.content_copy_outlined,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                    onPressed: () {
                      // TODO: Implémenter la copie du code
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
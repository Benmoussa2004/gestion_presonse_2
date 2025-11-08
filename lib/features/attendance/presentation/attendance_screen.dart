import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart' show AppRoutes;
import '../../../core/constants/roles.dart';
import '../../../core/widgets/role_badge.dart';
import '../../../core/widgets/admin_drawer.dart';
import '../../../mvc/providers.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _selectedClassId;
  String? _selectedSessionId;
  bool _tableView = false; // Mode tableau (toutes les séances) ou vue par séance

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserDocProvider).value;
    final bool isAdmin = me?.role == UserRoles.admin;
    final bool isTeacher = me?.role == UserRoles.teacher;
    final bool isStudent = me?.role == UserRoles.student;
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final classesCtrl = ref.watch(classesControllerProvider);
    final sessionsCtrl = ref.watch(sessionsControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Si c'est un étudiant, rediriger vers l'emploi du temps
    if (isStudent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppRoutes.studentSchedule);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
        final selectedClassId = _selectedClassId;

        return Scaffold(
          backgroundColor: colorScheme.background,
          appBar: AppBar(
            title: Text(
              'Gestion des Présences',
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
          // Les enseignants peuvent aussi voir et modifier les présences
          body: classesSnap.connectionState == ConnectionState.waiting
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : classes.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.class_outlined,
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
              ],
            ),
          )
              : Column(
            children: [
              // Sélection de la classe
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
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedClassId,
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
                        setState(() {
                          _selectedClassId = v;
                          _selectedSessionId = null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Classe',
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
                    const SizedBox(height: 12),
                    // Sélection de la séance
                    if (selectedClassId != null)
                      StreamBuilder<List<SessionModel>>(
                        stream: sessionsCtrl.watchForClass(selectedClassId),
                        builder: (context, sessSnap) {
                          final sessions = sessSnap.data ?? const <SessionModel>[];
                          if (sessions.isNotEmpty && (_selectedSessionId == null ||
                              !sessions.any((s) => s.id == _selectedSessionId))) {
                            _selectedSessionId = sessions.first.id;
                          }

                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: sessions.isEmpty
                                ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: colorScheme.onSurfaceVariant,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Aucune séance disponible',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : DropdownButtonFormField<String>(
                              value: _selectedSessionId,
                              items: [
                                for (final s in sessions)
                                  DropdownMenuItem(
                                    value: s.id,
                                    child: Text(
                                      '${s.name.isNotEmpty ? s.name : "Séance"} - ${s.startAt.day}/${s.startAt.month}/${s.startAt.year} ${s.startAt.hour}:${s.startAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _selectedSessionId = v),
                              decoration: InputDecoration(
                                labelText: 'Séance',
                                labelStyle: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                prefixIcon: Icon(
                                  Icons.event_outlined,
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
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bouton pour basculer entre vue tableau et vue par séance
              if (selectedClassId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Par séance'),
                        icon: Icon(Icons.list),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Tableau complet'),
                        icon: Icon(Icons.grid_view),
                      ),
                    ],
                    selected: {_tableView},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _tableView = newSelection.first;
                      });
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: selectedClassId == null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 64,
                        color: colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Choisissez une classe',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
                    : _tableView
                    ? _AttendanceTable(classId: selectedClassId!)
                    : (_selectedSessionId == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.checklist_rounded,
                                  size: 64,
                                  color: colorScheme.onSurface.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Choisissez une séance',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _AttendanceList(
                            classId: selectedClassId!,
                            sessionId: _selectedSessionId!,
                          )),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttendanceList extends ConsumerWidget {
  const _AttendanceList({required this.classId, required this.sessionId});
  final String classId;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesCtrl = ref.watch(classesControllerProvider);
    final usersCtrl = ref.watch(usersControllerProvider);
    final attendanceCtrl = ref.watch(attendanceControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<ClassModel>>(
      stream: classesCtrl.watchAll(),
      builder: (context, classesSnap) {
        final clazz = classesSnap.data?.firstWhere(
              (c) => c.id == classId,
          orElse: () => ClassModel(
              id: '', name: '', teacherId: '', studentIds: const [], createdAt: DateTime.fromMillisecondsSinceEpoch(0)),
        );
        final studentIds = clazz?.studentIds ?? const <String>[];

        return StreamBuilder<List<AttendanceModel>>(
          stream: attendanceCtrl.watchForSession(sessionId),
          builder: (context, attSnap) {
            final records = {for (final a in (attSnap.data ?? const <AttendanceModel>[])) a.studentId: a};

            if (studentIds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun étudiant dans cette classe',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: studentIds.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: colorScheme.outline.withOpacity(0.2),
                ),
                itemBuilder: (context, i) {
                  final sid = studentIds[i];
                  return StreamBuilder<AppUser?>(
                    stream: usersCtrl.watchUser(sid),
                    builder: (context, userSnap) {
                      final u = userSnap.data;
                      final rec = records[sid];
                      final status = rec?.status ?? 'absent';
                      final present = status == 'present';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: present
                              ? colorScheme.primaryContainer.withOpacity(0.3)
                              : colorScheme.surfaceVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: present
                                  ? colorScheme.primary.withOpacity(0.1)
                                  : colorScheme.onSurface.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              present ? Icons.check_circle_outline : Icons.person_outline,
                              color: present ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            u?.name ?? 'Étudiant',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            u?.email ?? sid,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: present,
                              onChanged: (v) async {
                                await attendanceCtrl.setStatus(
                                  sessionId: sessionId,
                                  studentId: sid,
                                  status: v ? 'present' : 'absent',
                                );
                              },
                              activeColor: colorScheme.primary,
                              trackColor: MaterialStateProperty.resolveWith((states) {
                                if (states.contains(MaterialState.selected)) {
                                  return colorScheme.primary.withOpacity(0.5);
                                }
                                return colorScheme.onSurface.withOpacity(0.2);
                              }),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _AttendanceTable extends ConsumerWidget {
  const _AttendanceTable({required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesCtrl = ref.watch(classesControllerProvider);
    final sessionsCtrl = ref.watch(sessionsControllerProvider);
    final attendanceCtrl = ref.watch(attendanceControllerProvider);
    final usersCtrl = ref.watch(usersControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<ClassModel>>(
      stream: classesCtrl.watchAll(),
      builder: (context, classesSnap) {
        final clazz = classesSnap.data?.firstWhere(
          (c) => c.id == classId,
          orElse: () => ClassModel(
              id: '', name: '', teacherId: '', studentIds: const [], createdAt: DateTime.fromMillisecondsSinceEpoch(0)),
        );
        final studentIds = clazz?.studentIds ?? const <String>[];

        return StreamBuilder<List<SessionModel>>(
          stream: sessionsCtrl.watchForClass(classId),
          builder: (context, sessionsSnap) {
            final sessions = sessionsSnap.data ?? [];
            
            if (sessions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.table_chart_outlined,
                      size: 64,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune séance disponible',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (studentIds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun étudiant dans cette classe',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Récupérer les présences pour toutes les séances
            return _AttendanceTableContent(
              classId: classId,
              studentIds: studentIds,
              sessions: sessions,
              attendanceCtrl: attendanceCtrl,
              usersCtrl: usersCtrl,
            );
          },
        );
      },
    );
  }
}

class _AttendanceTableContent extends ConsumerWidget {
  const _AttendanceTableContent({
    required this.classId,
    required this.studentIds,
    required this.sessions,
    required this.attendanceCtrl,
    required this.usersCtrl,
  });

  final String classId;
  final List<String> studentIds;
  final List<SessionModel> sessions;
  final dynamic attendanceCtrl;
  final dynamic usersCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          // En-tête fixe avec les noms des séances
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Colonne fixe pour les noms des étudiants
                  Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.5),
                      border: Border(
                        right: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      'Étudiant',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Colonnes pour chaque séance
                  ...sessions.map((session) {
                    return Container(
                      width: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.name.isNotEmpty ? session.name : 'Séance',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${session.startAt.day}/${session.startAt.month}/${session.startAt.year}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          // Corps du tableau avec scroll vertical et horizontal
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: studentIds.map((studentId) {
                    return _AttendanceTableRow(
                      studentId: studentId,
                      sessions: sessions,
                      attendanceCtrl: attendanceCtrl,
                      usersCtrl: usersCtrl,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTableRow extends ConsumerWidget {
  const _AttendanceTableRow({
    required this.studentId,
    required this.sessions,
    required this.attendanceCtrl,
    required this.usersCtrl,
  });

  final String studentId;
  final List<SessionModel> sessions;
  final dynamic attendanceCtrl;
  final dynamic usersCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<AppUser?>(
      stream: usersCtrl.watchUser(studentId),
      builder: (context, userSnap) {
        final user = userSnap.data;

        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Cellule fixe avec le nom de l'étudiant
              Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.2),
                  border: Border(
                    right: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.name ?? 'Étudiant',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user?.email != null)
                      Text(
                        user!.email,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Cellules pour chaque séance
              ...sessions.map((session) {
                return _AttendanceCell(
                  studentId: studentId,
                  sessionId: session.id,
                  attendanceCtrl: attendanceCtrl,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _AttendanceCell extends ConsumerWidget {
  const _AttendanceCell({
    required this.studentId,
    required this.sessionId,
    required this.attendanceCtrl,
  });

  final String studentId;
  final String sessionId;
  final dynamic attendanceCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<AttendanceModel>>(
      stream: attendanceCtrl.watchForSession(sessionId),
      builder: (context, attSnap) {
        final records = attSnap.data ?? [];
        final record = records.firstWhere(
          (a) => a.studentId == studentId,
          orElse: () => AttendanceModel(
            id: '',
            sessionId: sessionId,
            studentId: studentId,
            status: 'absent',
            markedAt: DateTime.now(),
          ),
        );
        final present = record.status == 'present';

        return GestureDetector(
          onTap: () async {
            await attendanceCtrl.setStatus(
              sessionId: sessionId,
              studentId: studentId,
              status: present ? 'absent' : 'present',
            );
          },
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: present
                  ? colorScheme.primaryContainer.withOpacity(0.3)
                  : colorScheme.surfaceVariant.withOpacity(0.1),
              border: Border(
                right: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Icon(
                present ? Icons.check_circle : Icons.cancel,
                color: present
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.3),
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }
}

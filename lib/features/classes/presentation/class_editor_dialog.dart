import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../../../core/constants/roles.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/class_model.dart';
import '../../../mvc/providers.dart';


Future<void> showClassEditorDialog(BuildContext context, WidgetRef ref,
    {ClassModel? existing}) async {
  await showDialog(
    context: context,
    builder: (_) => _ClassEditorDialog(existing: existing),
  );
}

class _ClassEditorDialog extends ConsumerStatefulWidget {
  const _ClassEditorDialog({this.existing});
  final ClassModel? existing;

  @override
  ConsumerState<_ClassEditorDialog> createState() => _ClassEditorDialogState();
}

class _ClassEditorDialogState extends ConsumerState<_ClassEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String? _teacherId;
  final Set<String> _studentIds = <String>{};
  bool _saving = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _teacherId = existing.teacherId.isEmpty ? null : existing.teacherId;
      _studentIds
        ..clear()
        ..addAll(existing.studentIds);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_teacherId == null || _teacherId!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sélectionnez un enseignant')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(classesControllerProvider);
      final model = ClassModel(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        teacherId: _teacherId!,
        studentIds: _studentIds.toList(),
        createdAt: widget.existing?.createdAt ?? DateTime.now().toUtc(),
      );
      if (widget.existing == null) {
        await repo.create(model);
      } else {
        await repo.update(model);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur enregistrement: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importExcel() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }

      final bytes = result.files.first.bytes ?? await result.files.first.xFile.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fichier Excel vide ou invalide')));
        }
        return;
      }

      // Prendre la première feuille
      final sheet = excel.tables[excel.tables.keys.first]!;
      if (sheet.rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Feuille Excel vide')));
        }
        return;
      }

      // Détecter l'en-tête
      final headerRow = sheet.rows.first;
      final header = headerRow.map((cell) {
        final value = cell?.value;
        return value?.toString().trim().toLowerCase() ?? '';
      }).toList();
      
      final hasHeader = header.any((h) => 
        h.contains('email') || h.contains('studentid') || h.contains('id') || h.contains('étudiant'));
      
      final dataRows = hasHeader ? sheet.rows.skip(1) : sheet.rows;
      
      final List<String> emails = [];
      int emailColumnIndex = -1;
      
      // Trouver l'index de la colonne email
      if (hasHeader) {
        for (int i = 0; i < header.length; i++) {
          if (header[i].contains('email')) {
            emailColumnIndex = i;
            break;
          }
        }
      }

      for (final row in dataRows) {
        if (row.isEmpty) continue;
        
        String? emailValue;
        if (emailColumnIndex >= 0 && emailColumnIndex < row.length) {
          // Colonne email spécifique
          final cell = row[emailColumnIndex];
          emailValue = cell?.value?.toString().trim();
        } else {
          // Première colonne qui contient un email
          for (final cell in row) {
            final value = cell?.value?.toString().trim();
            if (value != null && value.contains('@')) {
              emailValue = value;
              break;
            }
          }
        }
        
        if (emailValue != null && emailValue.contains('@')) {
          emails.add(emailValue);
        }
      }

      if (emails.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun email trouvé dans le fichier Excel')),
          );
        }
        return;
      }

      final usersCtrl = ref.read(usersControllerProvider);
      final found = await usersCtrl.findByEmails(emails);
      final studentFound = found.where((u) => u.role == UserRoles.student).toList();
      final foundEmails = studentFound.map((e) => e.email.toLowerCase()).toSet();
      final notFound = emails.where((e) => !foundEmails.contains(e.toLowerCase())).toList();

      setState(() {
        _studentIds.addAll(studentFound.map((e) => e.id));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Import: ${studentFound.length} étudiants ajoutés, ${notFound.length} non trouvés.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import échoué: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersCtrl = ref.watch(usersControllerProvider);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing == null ? 'Nouvelle classe' : 'Modifier la classe',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la classe',
                        prefixIcon: Icon(Icons.class_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nom requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<AppUser>>(
                      stream: usersCtrl.watchByRole(UserRoles.teacher),
                      builder: (context, snapshot) {
                        final teachers = snapshot.data ?? const <AppUser>[];
                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _teacherId,
                          items: [
                            for (final t in teachers)
                              DropdownMenuItem(
                                value: t.id,
                                child: Text('${t.name} • ${t.email}'),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _teacherId = v),
                          decoration: const InputDecoration(
                            labelText: 'Enseignant',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Choisir un enseignant'
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Étudiants', style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: StreamBuilder<List<AppUser>>(
                        stream: usersCtrl.watchByRole(UserRoles.student),
                        builder: (context, snapshot) {
                          final students = snapshot.data ?? const <AppUser>[];
                          if (students.isEmpty) {
                            return const Center(child: Text('Aucun étudiant'));
                          }
                          return SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: _importing ? null : _importExcel,
                                    icon: _importing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.file_upload_outlined),
                                    label: const Text('Importer Excel'),
                                  ),
                                ),
                                for (final s in students)
                                  FilterChip(
                                    label: Text(s.name),
                                    selected: _studentIds.contains(s.id),
                                    onSelected: _saving
                                        ? null
                                        : (sel) => setState(() {
                                              if (sel) {
                                                _studentIds.add(s.id);
                                              } else {
                                                _studentIds.remove(s.id);
                                              }
                                            }),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => Navigator.of(context).pop(),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_outlined),
                          label: const Text('Enregistrer'),
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

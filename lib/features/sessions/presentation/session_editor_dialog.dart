import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mvc/providers.dart';
import '../../../data/models/session_model.dart';

Future<void> showSessionEditorDialog(BuildContext context, WidgetRef ref,
    {required String classId, SessionModel? existing}) async {
  await showDialog(
    context: context,
    builder: (_) => _SessionEditorDialog(classId: classId, existing: existing),
  );
}

class _SessionEditorDialog extends ConsumerStatefulWidget {
  const _SessionEditorDialog({required this.classId, this.existing});
  final String classId;
  final SessionModel? existing;

  @override
  ConsumerState<_SessionEditorDialog> createState() => _SessionEditorDialogState();
}

class _SessionEditorDialogState extends ConsumerState<_SessionEditorDialog> {
  late DateTime _startAt;
  late DateTime _endAt;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startAt = widget.existing?.startAt ?? now;
    _endAt = widget.existing?.endAt ?? now.add(const Duration(hours: 2));
    _nameCtrl.text = widget.existing?.name ?? '';
    _codeCtrl.text = widget.existing?.code ?? _randomCode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _randomCode() {
    final n = DateTime.now().millisecondsSinceEpoch % 1000000;
    return n.toString().padLeft(6, '0');
  }

  Future<void> _pickDateTime({required bool start}) async {
    final initial = start ? _startAt : _endAt;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (d == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      if (start) {
        _startAt = dt;
        if (_endAt.isBefore(_startAt)) _endAt = _startAt.add(const Duration(hours: 2));
      } else {
        _endAt = dt.isBefore(_startAt) ? _startAt.add(const Duration(hours: 2)) : dt;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Veuillez entrer un nom pour la séance')));
      return;
    }
    setState(() => _saving = true);
    try {
      final ctrl = ref.read(sessionsControllerProvider);
      final model = SessionModel(
        id: widget.existing?.id ?? '',
        classId: widget.classId,
        name: name,
        startAt: _startAt,
        endAt: _endAt,
        code: _codeCtrl.text.trim(),
        qrUrl: widget.existing?.qrUrl,
      );
      if (widget.existing == null) {
        await ctrl.create(model);
      } else {
        await ctrl.update(model);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur sauvegarde séance: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Nouvelle séance' : 'Modifier la séance',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom de la séance (ex: Math, Python, etc.)',
                hintText: 'Entrez le nom de la séance',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Début'),
                    subtitle: Text('${_startAt.day}/${_startAt.month}/${_startAt.year} ${_startAt.hour}:${_startAt.minute.toString().padLeft(2, '0')}'),
                    onTap: () => _pickDateTime(start: true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Fin'),
                    subtitle: Text('${_endAt.day}/${_endAt.month}/${_endAt.year} ${_endAt.hour}:${_endAt.minute.toString().padLeft(2, '0')}'),
                    onTap: () => _pickDateTime(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Code',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
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
    );
  }
}

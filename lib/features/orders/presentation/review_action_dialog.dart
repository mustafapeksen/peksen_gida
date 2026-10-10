import 'package:flutter/material.dart';

import '../../products/presentation/price_page.dart' show newOperationKey;

// Retain the exact request on uncertain failures; no silent automatic retry.
class ReviewActionDialog extends StatefulWidget {
  const ReviewActionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.send,
    this.requireNote = false,
  });
  final String title, message;
  final bool requireNote;
  final Future<void> Function(String note, String key) send;
  @override
  State<ReviewActionDialog> createState() => _ReviewActionDialogState();
}

class _ReviewActionDialogState extends State<ReviewActionDialog> {
  final note = TextEditingController();
  final key = newOperationKey();
  bool busy = false, sent = false;
  String? error;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (widget.requireNote && note.text.trim().isEmpty) {
      setState(() => error = 'Karar notu zorunludur.');
      return;
    }
    setState(() {
      busy = true;
      sent = true;
      error = null;
    });
    try {
      await widget.send(note.text.trim(), key);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'İşlem doğrulanamadı. Aynı isteği yeniden deneyin veya kapatıp listeyi yenileyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          if (widget.requireNote)
            TextField(
              controller: note,
              readOnly: sent,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Karar notu'),
            ),
          if (error != null) Text(error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? 'Kaydediliyor…'
                : sent
                ? 'Aynı isteği yeniden dene'
                : 'Onayla',
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

class AddDialogResult {
  final String title;
  final String description;

  AddDialogResult({required this.title, required this.description});
}

class AddDeepLinkDialog extends StatefulWidget {
  const AddDeepLinkDialog({super.key});

  @override
  State<AddDeepLinkDialog> createState() => _AddDeepLinkDialogState();
}

class _AddDeepLinkDialogState extends State<AddDeepLinkDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить запись'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              AddDialogResult(title: _title.text, description: _desc.text),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

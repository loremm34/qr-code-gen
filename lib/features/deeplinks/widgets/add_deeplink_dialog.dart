import 'package:flutter/material.dart';

class AddDialogResult {
  final String title;
  final String description;
  final String deepLink; // NEW

  AddDialogResult({
    required this.title,
    required this.description,
    required this.deepLink,
  });
}

class AddDeepLinkDialog extends StatefulWidget {
  const AddDeepLinkDialog({super.key});

  @override
  State<AddDeepLinkDialog> createState() => _AddDeepLinkDialogState();
}

class _AddDeepLinkDialogState extends State<AddDeepLinkDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _link = TextEditingController(); // NEW

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить запись'),
      content: SizedBox(
        width: 520,
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
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              decoration: const InputDecoration(
                labelText: 'Deep link (полностью)',
                hintText: 'example://open/123?x=1',
              ),
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
            final title = _title.text.trim();
            final link = _link.text.trim();
            if (title.isEmpty || link.isEmpty) return;

            Navigator.pop(
              context,
              AddDialogResult(
                title: title,
                description: _desc.text.trim(),
                deepLink: link,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

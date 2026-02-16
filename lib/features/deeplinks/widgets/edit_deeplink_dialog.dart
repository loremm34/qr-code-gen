import 'package:flutter/material.dart';

class EditDeepLinkDialog extends StatefulWidget {
  final String initialLink;

  const EditDeepLinkDialog({super.key, required this.initialLink});

  @override
  State<EditDeepLinkDialog> createState() => _EditDeepLinkDialogState();
}

class _EditDeepLinkDialogState extends State<EditDeepLinkDialog> {
  late final TextEditingController _link;

  @override
  void initState() {
    super.initState();
    _link = TextEditingController(text: widget.initialLink);
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать диплинк'),
      content: SizedBox(
        width: 560,
        child: TextField(
          controller: _link,
          decoration: const InputDecoration(
            labelText: 'Deep link',
            hintText: 'myapp://...',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final value = _link.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(context, value);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

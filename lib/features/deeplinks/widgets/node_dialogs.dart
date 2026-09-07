import 'package:flutter/material.dart';

import '../../../core/utils/scheme_utils.dart';

class LinkFormResult {
  final String title;
  final String description;

  /// Путь после `://`; пользователь мог вставить и полный линк.
  final String link;

  LinkFormResult({
    required this.title,
    required this.description,
    required this.link,
  });
}

/// Создание/переименование папки. Возвращает название либо null.
Future<String?> showFolderDialog(
  BuildContext context, {
  String initialTitle = '',
}) {
  final controller = TextEditingController(text: initialTitle);
  final isEdit = initialTitle.isNotEmpty;

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isEdit ? 'Переименовать папку' : 'Новая папка'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название',
            hintText: 'Например: Онбординг',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(context, value);
          },
          child: Text(isEdit ? 'Сохранить' : 'Создать'),
        ),
      ],
    ),
  );
}

/// Создание/редактирование диплинка.
Future<LinkFormResult?> showLinkDialog(
  BuildContext context, {
  required String scheme,
  String initialTitle = '',
  String initialDescription = '',
  String initialPath = '',
  bool isEdit = false,
}) {
  final title = TextEditingController(text: initialTitle);
  final description = TextEditingController(text: initialDescription);
  final path = TextEditingController(text: initialPath);

  return showDialog<LinkFormResult>(
    context: context,
    builder: (context) {
      void submit() {
        if (title.text.trim().isEmpty || path.text.trim().isEmpty) return;
        Navigator.pop(
          context,
          LinkFormResult(
            title: title.text.trim(),
            description: description.text.trim(),
            link: path.text.trim(),
          ),
        );
      }

      return AlertDialog(
        title: Text(isEdit ? 'Редактировать диплинк' : 'Новый диплинк'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: title,
                autofocus: !isEdit,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: path,
                autofocus: isEdit,
                decoration: InputDecoration(
                  labelText: 'Путь после ://',
                  prefixText: scheme,
                  hintText: 'open/123?utm=qr',
                ),
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 8),
              Text(
                'Можно вставить целый линк с любой схемой — она отделится '
                'сама, попадёт в список схем и закрепится за этим диплинком '
                '(он перестанет зависеть от активной схемы).',
                style: Theme.of(context).textTheme.bodySmall,
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
            onPressed: submit,
            child: Text(isEdit ? 'Сохранить' : 'Создать'),
          ),
        ],
      );
    },
  );
}

/// Ввод схемы (всё, что до `://`).
Future<String?> showSchemeDialog(
  BuildContext context, {
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  final isEdit = initial.isNotEmpty;

  return showDialog<String>(
    context: context,
    builder: (context) {
      String preview(String raw) {
        final normalized = SchemeUtils.normalize(raw);
        return normalized.isEmpty ? '—' : normalized;
      }

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Переименовать схему' : 'Новая схема'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Схема',
                    hintText: 'myapp',
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    if (SchemeUtils.normalize(value).isNotEmpty) {
                      Navigator.pop(context, value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Будет сохранено как: ${preview(controller.text)}',
                  style: Theme.of(context).textTheme.bodySmall,
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
                if (SchemeUtils.normalize(controller.text).isEmpty) return;
                Navigator.pop(context, controller.text);
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      );
    },
  );
}

/// Подтверждение удаления.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

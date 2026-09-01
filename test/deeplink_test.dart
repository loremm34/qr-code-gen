import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_qr_gen/app/app.dart';
import 'package:flutter_qr_gen/core/utils/scheme_utils.dart';
import 'package:flutter_qr_gen/data/repositories/deeplink_repository.dart';
import 'package:flutter_qr_gen/data/storage/local_storage.dart';
import 'package:flutter_qr_gen/features/deeplinks/controller/deeplink_controller.dart';

DeepLinkController _controller() =>
    DeepLinkController(DeepLinkRepository(LocalStorage()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SchemeUtils', () {
    test('нормализует любой ввод к виду scheme://', () {
      expect(SchemeUtils.normalize('myapp'), 'myapp://');
      expect(SchemeUtils.normalize('myapp:'), 'myapp://');
      expect(SchemeUtils.normalize('myapp://'), 'myapp://');
      expect(SchemeUtils.normalize(' myapp://open/1 '), 'myapp://');
      expect(SchemeUtils.normalize('   '), '');
    });

    test('делит полный линк на схему и хвост', () {
      expect(SchemeUtils.schemeOf('myapp://open/1?x=2'), 'myapp://');
      expect(SchemeUtils.tailOf('myapp://open/1?x=2'), 'open/1?x=2');
      expect(SchemeUtils.schemeOf('open/1'), isNull);
      expect(SchemeUtils.tailOf('open/1'), 'open/1');
      expect(SchemeUtils.tailOf('myapp:///open/1'), 'open/1');
    });

    test('собирает линк обратно', () {
      expect(SchemeUtils.compose('myapp', '/open/1'), 'myapp://open/1');
    });
  });

  group('Дерево', () {
    test('папки и диплинки складываются в иерархию', () async {
      final c = _controller();
      await c.init();

      final folder = await c.createFolder(title: 'Онбординг');
      final nested = await c.createFolder(parentId: folder, title: 'Экраны');
      await c.createLink(
        parentId: nested,
        title: 'Welcome',
        rawLink: 'open/welcome',
      );

      expect(c.childrenOf(null).single.id, folder);
      expect(c.childrenOf(folder).single.id, nested);
      expect(c.countLinksIn(folder), 1);
      expect(c.ancestorsOf(nested).single.title, 'Онбординг');
    });

    test('новый узел ложится рядом с выбранным диплинком', () async {
      final c = _controller();
      await c.init();

      final folder = await c.createFolder(title: 'Папка');
      final link = await c.createLink(
        parentId: folder,
        title: 'Ссылка',
        rawLink: 'open/1',
      );
      final sibling = await c.createFolder(parentId: link, title: 'Соседняя');

      expect(c.nodeById(sibling)!.parentId, folder);
    });

    test('папку нельзя перенести внутрь самой себя', () async {
      final c = _controller();
      await c.init();

      final parent = await c.createFolder(title: 'Родитель');
      final child = await c.createFolder(parentId: parent, title: 'Ребёнок');

      expect(c.canDropInto(parent, child), isFalse);
      expect(await c.move(parent, child), isFalse);
      expect(c.nodeById(parent)!.parentId, isNull);
    });

    test('удаление папки уносит всё вложенное', () async {
      final c = _controller();
      await c.init();

      final folder = await c.createFolder(title: 'Папка');
      final nested = await c.createFolder(parentId: folder, title: 'Вложенная');
      await c.createLink(parentId: nested, title: 'Ссылка', rawLink: 'open/1');

      await c.delete(folder);
      expect(c.nodes, isEmpty);
      expect(c.selectedId, isNull);
    });
  });

  group('Схемы', () {
    test('переключение схемы меняет все диплинки разом', () async {
      final c = _controller();
      await c.init();

      final id = await c.createLink(
        title: 'Ссылка',
        rawLink: 'example://open/1',
      );
      expect(c.fullLink(c.nodeById(id)!), 'example://open/1');

      await c.addScheme('myapp');
      expect(c.fullLink(c.nodeById(id)!), 'myapp://open/1');
    });

    test('схема из вставленного линка попадает в список, но не активируется',
        () async {
      final c = _controller();
      await c.init();

      final before = c.selectedScheme;
      await c.createLink(title: 'Ссылка', rawLink: 'other://open/2');

      expect(c.schemes, contains('other://'));
      expect(c.selectedScheme, before);
    });

    test('последнюю схему удалить нельзя', () async {
      final c = _controller();
      await c.init();

      await c.deleteScheme(c.selectedScheme);
      expect(c.schemes, hasLength(1));
    });
  });

  group('Экспорт и импорт', () {
    test('экспорт и импорт с заменой сохраняют дерево', () async {
      final source = _controller();
      await source.init();

      final folder = await source.createFolder(title: 'Папка');
      await source.createLink(
        parentId: folder,
        title: 'Ссылка',
        description: 'Описание',
        rawLink: 'open/1',
      );
      final exported = source.exportToJsonString();

      final target = _controller();
      await target.init();
      await target.importFromJsonString(exported, replace: true);

      final restoredFolder = target.childrenOf(null).single;
      expect(restoredFolder.title, 'Папка');

      final restoredLink = target.childrenOf(restoredFolder.id).single;
      expect(restoredLink.path, 'open/1');
      expect(restoredLink.description, 'Описание');
    });

    test('импорт без замены дублирует дерево с новыми id', () async {
      final c = _controller();
      await c.init();
      await c.createFolder(title: 'Папка');

      final exported = c.exportToJsonString();
      await c.importFromJsonString(exported, replace: false);

      final roots = c.childrenOf(null);
      expect(roots, hasLength(2));
      expect(roots.first.id, isNot(roots.last.id));
    });

    test('читается старый формат с вкладками iOS/Android', () async {
      final c = _controller();
      await c.init();

      await c.importFromJsonString(
        jsonEncode({
          'version': 1,
          'ios': {
            'prefixes': ['example://'],
            'selectedPrefix': 'example://',
            'items': [
              {
                'id': 'a',
                'title': 'iOS ссылка',
                'description': '',
                'deepLink': 'example://open/ios',
              },
            ],
          },
          'android': {
            'items': [
              {
                'id': 'b',
                'title': 'Android ссылка',
                'description': '',
                'deepLink': 'myapp://open/android?platform=android',
              },
            ],
          },
        }),
      );

      final roots = c.childrenOf(null);
      expect(roots.map((e) => e.title), ['iOS ссылка', 'Android ссылка']);
      expect(roots.last.path, 'open/android?platform=android');
      expect(c.schemes, containsAll(['example://', 'myapp://']));
    });
  });

  group('Экран', () {
    testWidgets('папка создаётся через панель слева', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.text('Создай папку или диплинк слева'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.create_new_folder_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Онбординг');
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();

      // Название видно и в дереве слева, и в хлебных крошках справа.
      expect(find.text('Онбординг'), findsWidgets);
      expect(find.text('Папка пуста'), findsOneWidget);
    });
  });

  group('Миграция хранилища', () {
    test('старые ключи переезжают в дерево при первом запуске', () async {
      SharedPreferences.setMockInitialValues({
        'items_ios': jsonEncode([
          {
            'id': 'a',
            'title': 'Старая ссылка',
            'description': '',
            'deepLink': 'example://open/old',
          },
        ]),
        'ios_prefixes': ['example://', 'legacy://'],
        'ios_selected_prefix': 'legacy://',
      });

      final c = _controller();
      await c.init();

      expect(c.childrenOf(null).single.title, 'Старая ссылка');
      expect(c.selectedScheme, 'legacy://');
      expect(c.schemes, containsAll(['example://', 'legacy://']));
    });
  });
}

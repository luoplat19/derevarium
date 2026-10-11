import 'dart:async';
import 'dart:convert';

import 'package:derevarium/main.dart';
import 'package:derevarium/plantnet_api.dart';
import 'package:derevarium/tree_facts_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

Tree sampleTree({String location = 'Чернівці', String notes = ''}) => Tree(
  type: 'Дуб',
  location: location,
  locationType: 'Місто',
  facts: 'Дуб — довговічне дерево.',
  notes: notes,
  dateFound: DateTime(2026, 10, 11),
);

class TestPreferences extends InMemorySharedPreferencesStore {
  TestPreferences(super.data) : super.withData();
  bool rejectWrites = false;
  bool throwOnWrite = false;
  bool rejectReads = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (throwOnWrite) throw StateError('Quota exceeded');
    if (rejectWrites) return false;
    return super.setValue(valueType, key, value);
  }

  @override
  Future<Map<String, Object>> getAll() async {
    if (rejectReads) throw StateError('Storage unavailable');
    return super.getAll();
  }
}

Future<void> mountHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const TreeApp());
  await tester.pumpAndSettle();
}

Future<void> openBestiaryEditor(WidgetTester tester) async {
  await tester.tap(find.text('Бестіарій'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Дуб'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Знахідка №1'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit));
  await tester.pumpAndSettle();
}

Future<void> saveEditor(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Зберегти зміни');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class StalledBodyClient extends http.BaseClient {
  final body = StreamController<List<int>>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(body.stream, 200);
  @override
  void close() {
    body.close();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Loads valid trees and preserves unreadable records on save', (
    tester,
  ) async {
    final original = jsonEncode(sampleTree().toJson());
    final invalidType = jsonEncode({'type': 42});
    final store = TestPreferences({
      'flutter.trees': [original, '{broken', invalidType],
    });
    SharedPreferencesStorePlatform.instance = store;
    await mountHome(tester);
    final dynamic home = tester.state(
      find.byType(HomePage, skipOffstage: false),
    );
    expect(home.trees, hasLength(1));
    expect(
      find.textContaining('Не вдалося прочитати 2 записів'),
      findsOneWidget,
    );
    expect(
      await home.applyTreeAction(
        TreeAction(tree: sampleTree(notes: 'Новий запис')),
      ),
      isTrue,
    );
    final persisted = (await store.getAll())['flutter.trees'] as List<String>;
    expect(persisted, hasLength(4));
    expect(persisted, containsAll(['{broken', invalidType]));
    await tester.pumpWidget(const SizedBox());
    await mountHome(tester);
    final dynamic reloaded = tester.state(find.byType(HomePage));
    expect(reloaded.trees, hasLength(2));
  });
  testWidgets('Edits from the bestiary persist and survive reopening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'trees': [jsonEncode(sampleTree().toJson())],
    });
    await mountHome(tester);
    await openBestiaryEditor(tester);
    final notes = find.widgetWithText(TextField, '❤️ Наша історія');
    await tester.ensureVisible(notes);
    await tester.enterText(notes, 'Знайшли разом біля парку');
    await saveEditor(tester);
    expect(find.byType(AddTreePage), findsNothing);
    expect(
      jsonDecode(
        (await SharedPreferences.getInstance()).getStringList('trees')!.single,
      )['notes'],
      'Знайшли разом біля парку',
    );
    await tester.pumpWidget(const SizedBox());
    await mountHome(tester);
    await openBestiaryEditor(tester);
    final dynamic editor = tester.state(find.byType(AddTreePage));
    expect(editor.notesController.text, 'Знайшли разом біля парку');
  });
  testWidgets('Deletes from the bestiary update collection and storage', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'trees': [jsonEncode(sampleTree().toJson())],
    });
    await mountHome(tester);
    await openBestiaryEditor(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Видалити'));
    await tester.pumpAndSettle();
    final dynamic home = tester.state(find.byType(HomePage));
    expect(home.trees, isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getStringList('trees'),
      isEmpty,
    );
    expect(find.byType(AddTreePage), findsNothing);
  });
  for (final throwsError in [false, true]) {
    testWidgets(
      'A ${throwsError ? 'throwing' : 'rejected'} write keeps the form and allows retry',
      (tester) async {
        final original = jsonEncode(sampleTree(notes: 'Оригінал').toJson());
        final store = TestPreferences({
          'flutter.trees': [original],
        });
        SharedPreferencesStorePlatform.instance = store;
        await mountHome(tester);
        await openBestiaryEditor(tester);
        final notes = find.widgetWithText(TextField, '❤️ Наша історія');
        await tester.ensureVisible(notes);
        await tester.enterText(notes, 'Зміна');
        store.rejectWrites = !throwsError;
        store.throwOnWrite = throwsError;
        await saveEditor(tester);
        expect(find.byType(AddTreePage), findsOneWidget);
        expect(
          find.textContaining('Не вдалося зберегти зміни'),
          findsOneWidget,
        );
        expect((await store.getAll())['flutter.trees'], [original]);
        expect((await SharedPreferences.getInstance()).getStringList('trees'), [
          original,
        ]);
        final dynamic home = tester.state(
          find.byType(HomePage, skipOffstage: false),
        );
        expect((home.trees.single as Tree).notes, 'Оригінал');
        store.rejectWrites = false;
        store.throwOnWrite = false;
        await tester.pump(const Duration(seconds: 9));
        await tester.pumpAndSettle();
        await saveEditor(tester);
        expect(find.byType(AddTreePage), findsNothing);
        expect(
          jsonDecode(
            ((await store.getAll())['flutter.trees'] as List<String>).single,
          )['notes'],
          'Зміна',
        );
      },
    );
  }
  testWidgets('Failed deletion keeps the old tree', (tester) async {
    final original = jsonEncode(sampleTree().toJson());
    final store = TestPreferences({
      'flutter.trees': [original],
    });
    SharedPreferencesStorePlatform.instance = store;
    await mountHome(tester);
    await openBestiaryEditor(tester);
    store.throwOnWrite = true;
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Видалити'));
    await tester.pumpAndSettle();
    expect(find.byType(AddTreePage), findsOneWidget);
    expect((await store.getAll())['flutter.trees'], [original]);
  });
  testWidgets('Storage read failure prevents overwriting the old collection', (
    tester,
  ) async {
    final store = TestPreferences({})..rejectReads = true;
    SharedPreferencesStorePlatform.instance = store;
    await mountHome(tester);
    final dynamic home = tester.state(find.byType(HomePage));
    expect(await home.applyTreeAction(TreeAction(tree: sampleTree())), isFalse);
    expect(
      find.textContaining('Не вдалося прочитати збережені дерева'),
      findsOneWidget,
    );
    store.rejectReads = false;
    await home.loadTrees();
    expect(await home.applyTreeAction(TreeAction(tree: sampleTree())), isTrue);
    await tester.pump();
  });
  testWidgets('Map searches new locations without recreating its state', (
    tester,
  ) async {
    final queries = <String>[];
    await http.runWithClient(
      () async {
        final trees = <Tree>[];
        await tester.pumpWidget(MaterialApp(home: MapPage(trees: trees)));
        await tester.pumpAndSettle();
        final firstState = tester.state(find.byType(MapPage));
        trees.add(sampleTree(location: 'Деражня'));
        await tester.pumpWidget(MaterialApp(home: MapPage(trees: trees)));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(MapPage)), same(firstState));
        expect(queries, ['деражня']);
        final dynamic map = firstState;
        expect(map.getCoordinates('Деражня'), isNotNull);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((request) async {
        queries.add(request.url.queryParameters['q']!);
        return http.Response('[{"lat":"49.27","lon":"27.44"}]', 200);
      }),
    );
  });
  testWidgets('Map recovers from a geocoding timeout and failed cache writes', (
    tester,
  ) async {
    SharedPreferencesStorePlatform.instance = TestPreferences({})
      ..throwOnWrite = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: MapPage(trees: [sampleTree(location: 'Деражня')]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text('Шукаємо локації на карті...'), findsNothing);
      expect(find.textContaining('Деякі локації'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) => Completer<http.Response>().future));
  });
  testWidgets('Wikipedia has a deadline even if requests never finish', (
    tester,
  ) async {
    TreeFactsResult? result;
    bool finished = false;
    http.runWithClient(() {
      TreeFactsApi.getFacts(commonName: 'Дуб', scientificName: 'Quercus').then((
        value,
      ) {
        result = value;
        finished = true;
      });
    }, () => MockClient((_) => Completer<http.Response>().future));
    await tester.pump(const Duration(seconds: 21));
    expect(finished, isTrue);
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 30));
  });
  test('Wikipedia falls back to the scientific name', () async {
    final result = await http.runWithClient(
      () => TreeFactsApi.getFacts(
        commonName: 'Unknown oak',
        scientificName: 'Quercus',
      ),
      () => MockClient((request) async {
        if (request.url.path.endsWith('Quercus')) {
          return http.Response(
            jsonEncode({
              'extract': 'Дуб — рід багаторічних рослин родини букових.',
              'content_urls': {
                'desktop': {'page': 'https://uk.wikipedia.org/wiki/Дуб'},
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('', 404);
      }),
    );
    expect(result?.facts, contains('Дуб'));
    expect(result?.sourceUrl, contains('/wiki/'));
  });
  testWidgets('PlantNet times out while waiting for the response body', (
    tester,
  ) async {
    Object? error;
    final bytes = img.encodeJpg(img.Image(width: 2, height: 2));
    http.runWithClient(() {
      PlantNetApi.identify(bytes).then(
        (_) {},
        onError: (Object value) {
          error = value;
        },
      );
    }, StalledBodyClient.new);
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    expect(error.toString(), contains('не відповів вчасно'));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/widgets/pems_components.dart';
import 'package:pasora/features/catalog/domain/photo_repository.dart';
import 'package:pasora/features/catalog/presentation/photo_source_sheet.dart';

void main() {
  testWidgets('le sélecteur moderne remplace le menu Android et accepte null', (
    tester,
  ) async {
    String? selected = 'boutique';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PemsDropdownField<String?>(
            value: selected,
            label: 'Filtrer par boutique',
            items: const [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Toutes les boutiques'),
              ),
              DropdownMenuItem<String?>(
                value: 'boutique',
                child: Text('Boutique Akwa'),
              ),
            ],
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Boutique Akwa'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
    expect(find.text('Toutes les boutiques'), findsOneWidget);
    await tester.tap(find.text('Toutes les boutiques'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('les deux sources de photo sont disponibles', (tester) async {
    PemsPhotoSource? source;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                source = await showPemsPhotoSourceSheet(context);
              },
              child: const Text('Photo'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    expect(source, PemsPhotoSource.camera);

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();
    expect(source, PemsPhotoSource.gallery);
  });

  testWidgets('une longue liste reste utilisable sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PemsDropdownField<String>(
            value: selected,
            label: 'Boutique',
            items: List.generate(
              12,
              (index) => DropdownMenuItem(
                value: 'shop-$index',
                child: Text('Boutique $index'),
              ),
            ),
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();
    expect(find.text('Rechercher…'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Boutique 11');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boutique 11').last);
    await tester.pumpAndSettle();
    expect(selected, 'shop-11');
    expect(tester.takeException(), isNull);
  });
}

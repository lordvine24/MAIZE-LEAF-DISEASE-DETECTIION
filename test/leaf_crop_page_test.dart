import 'dart:typed_data';

import 'package:chloroscan/features/home/ui/leaf_crop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  testWidgets('returns the selected leaf crop for scanning', (tester) async {
    final original = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 100, height: 200)),
    );
    Uint8List? croppedBytes;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                croppedBytes = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute<Uint8List>(
                    builder: (_) => LeafCropPage(imageBytes: original),
                  ),
                );
              },
              child: const Text('Open crop'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open crop'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.tap(find.text('Crop and scan'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final decoded = img.decodeImage(croppedBytes!);
    expect(decoded, isNotNull);
    expect(decoded!.width, 70);
    expect(decoded.height, 160);
  });
}

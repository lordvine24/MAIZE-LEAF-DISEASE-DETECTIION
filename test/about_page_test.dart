import 'package:chloroscan/features/profile/ui/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows scan instructions and supported conditions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const AboutPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How to use the app'), findsOneWidget);
    expect(find.text('Choose a leaf photo'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Gray Leaf Spot'), 400);
    expect(find.text('Gray Leaf Spot'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Northern Corn Leaf Blight'),
      400,
    );
    expect(find.text('Northern Corn Leaf Blight'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start a scan'), 400);
    expect(find.text('Start a scan'), findsOneWidget);
  });
}
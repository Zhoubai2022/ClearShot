import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imageupload/main.dart';

void main() {
  testWidgets('App starts and shows initial state', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that our initial state is correct.
    expect(find.text('No image selected.'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNWidgets(2));
  });

  testWidgets('Pick Image button is clickable', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Tap the 'Pick Image' button and trigger a frame.
    await tester.tap(find.text('Pick Image'));
    await tester.pump();

    // We cannot test actual image picking in unit tests as it involves platform-specific code,
    // but we can ensure the button exists and is tappable.
    expect(find.text('Pick Image'), findsOneWidget);
  });

  testWidgets('Upload Image button is clickable', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Tap the 'Upload Image' button and trigger a frame.
    await tester.tap(find.text('Upload Image'));
    await tester.pump();

    // We cannot test actual upload functionality in unit tests as it involves network operations,
    // but we can ensure the button exists and is tappable.
    expect(find.text('Upload Image'), findsOneWidget);
  });
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mockito/mockito.dart';

// Use the right package name here
import 'package:shopping_list/main.dart';

// Mock Firebase initialization
class MockFirebaseApp extends Mock implements FirebaseApp {}

void main() {
  // Setup mock for Firebase
  setupFirebaseAuthMocks();

  testWidgets('Shopping list app UI test', (WidgetTester tester) async {
    // Initialize mock Firebase
    await Firebase.initializeApp();

    // Build our app and trigger a frame
    await tester.pumpWidget(const MyApp());

    // Verify app bar title is present
    expect(find.text('Shopping List'), findsOneWidget);

    // Verify input fields are present
    expect(find.byType(TextField), findsNWidgets(2));

    // Verify add button is present
    expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);

    // Initially, we should see the empty state message
    expect(find.text('Your shopping list is empty'), findsOneWidget);
  });
}

// Mock setup for Firebase
void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

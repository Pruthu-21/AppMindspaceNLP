import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mindspace_nlp/main.dart';
import 'package:mindspace_nlp/services/auth_manager.dart';

class RealHttpOverrides extends HttpOverrides {}

class MyMockPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
  @override
  Future<String?> getTemporaryPath() async => '.';
  @override
  Future<String?> getLibraryPath() async => '.';
  @override
  Future<String?> getApplicationSupportPath() async => '.';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = RealHttpOverrides();
    PathProviderPlatform.instance = MyMockPathProvider();
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Run the startup and rendering inside runAsync to handle socket timers
    await tester.runAsync(() async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MindSpaceDriveApp());
      
      // Wait for widgets to settle and async session storage check to finish
      await tester.pump();
      await tester.idle();
      await tester.pump();
    });

    // Verify that LoginPage elements are present.
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}

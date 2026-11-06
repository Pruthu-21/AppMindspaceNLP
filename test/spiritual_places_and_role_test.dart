import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindspace_nlp/services/role_manager.dart';
import 'package:mindspace_nlp/features/spiritual_places/models/spiritual_place.dart';
import 'package:mindspace_nlp/features/spiritual_places/services/spiritual_zone_service.dart';
import 'package:mindspace_nlp/widgets/expandable_fab_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoleManager Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      RoleManager.roleNotifier.value = AppRole.user;
    });

    test('Default role is user', () {
      expect(RoleManager.isUser, isTrue);
      expect(RoleManager.isAdmin, isFalse);
    });

    test('switchRole toggles role and persists preference', () async {
      await RoleManager.switchRole(AppRole.admin);
      expect(RoleManager.isAdmin, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('admin_console_mode_preference'), 'admin');

      await RoleManager.switchRole(AppRole.user);
      expect(RoleManager.isUser, isTrue);
      expect(prefs.getString('admin_console_mode_preference'), 'user');
    });

    test(
      'resolveInitialRole respects admin preference across app sessions',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // Normal user always resolves to user regardless of preference
        await prefs.setString('admin_console_mode_preference', 'admin');
        final userRole = await RoleManager.resolveInitialRole(AppRole.user);
        expect(userRole, AppRole.user);
        expect(RoleManager.isAdmin, isFalse);

        // Admin with 'user' preference resolves to user mode
        await prefs.setString('admin_console_mode_preference', 'user');
        final adminInUserMode = await RoleManager.resolveInitialRole(
          AppRole.admin,
        );
        expect(adminInUserMode, AppRole.user);
        expect(RoleManager.isUser, isTrue);

        // Admin with 'admin' preference resolves to admin mode
        await prefs.setString('admin_console_mode_preference', 'admin');
        final adminInAdminMode = await RoleManager.resolveInitialRole(
          AppRole.admin,
        );
        expect(adminInAdminMode, AppRole.admin);
        expect(RoleManager.isAdmin, isTrue);
      },
    );
  });

  group('SpiritualZoneService Tests', () {
    const place = SpiritualPlace(
      id: 'test_place',
      name: 'Pavagadh Mahakali Temple',
      region: 'Panchmahal, Gujarat',
      latitude: 22.4850,
      longitude: 73.5330,
      category: 'Shakti Peeth',
      description: 'Test Description',
      innerRadius: 200,
      outerRadius: 1000,
    );

    test('Calculates High Intensity Zone within inner radius (<200m)', () {
      // Coordinates ~50m from center
      const userLat = 22.4852;
      const userLon = 73.5332;

      final zone = SpiritualZoneService.getZone(place, userLat, userLon);
      expect(zone, SpiritualZone.highIntensity);
      expect(SpiritualZoneService.getIntensityMultiplier(zone), 2.0);
      expect(SpiritualZoneService.getZoneName(zone), 'High Intensity Zone');
    });

    test(
      'Calculates Low Intensity Zone within outer perimeter (200m - 1000m)',
      () {
        // Coordinates ~450m from center
        const userLat = 22.4880;
        const userLon = 73.5330;

        final zone = SpiritualZoneService.getZone(place, userLat, userLon);
        expect(zone, SpiritualZone.lowIntensity);
        expect(SpiritualZoneService.getIntensityMultiplier(zone), 1.5);
        expect(SpiritualZoneService.getZoneName(zone), 'Low Intensity Zone');
      },
    );

    test('Calculates Outside Zone beyond outer perimeter (>1000m)', () {
      // Ahmedabad coordinates (~110km away)
      const userLat = 23.0225;
      const userLon = 72.5714;

      final zone = SpiritualZoneService.getZone(place, userLat, userLon);
      expect(zone, SpiritualZone.outside);
      expect(SpiritualZoneService.getIntensityMultiplier(zone), 1.0);
      expect(SpiritualZoneService.getZoneName(zone), 'Outside Spiritual Zones');
    });
  });

  group('ExpandableFabMenu Widget Tests', () {
    testWidgets('Renders closed state with plus icon', (tester) async {
      bool toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: ExpandableFabMenu(
              isOpen: false,
              onToggle: () => toggled = true,
              onClose: () {},
              items: [
                FabMenuItem(
                  label: 'Add / Upload',
                  icon: Icons.add,
                  onTap: () {},
                ),
                FabMenuItem(
                  label: 'Spiritual Places',
                  icon: Icons.location_on,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      expect(toggled, isTrue);
    });

    testWidgets('Renders open state and triggers item tap callback', (
      tester,
    ) async {
      bool addTapped = false;
      bool placesTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: ExpandableFabMenu(
              isOpen: true,
              onToggle: () {},
              onClose: () {},
              items: [
                FabMenuItem(
                  label: 'Add / Upload',
                  icon: Icons.add,
                  onTap: () => addTapped = true,
                ),
                FabMenuItem(
                  label: 'Spiritual Places',
                  icon: Icons.location_on,
                  onTap: () => placesTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add / Upload'), findsOneWidget);
      expect(find.text('Spiritual Places'), findsOneWidget);

      await tester.tap(find.text('Spiritual Places'));
      expect(placesTapped, isTrue);

      await tester.tap(find.text('Add / Upload'));
      expect(addTapped, isTrue);
    });
  });
}

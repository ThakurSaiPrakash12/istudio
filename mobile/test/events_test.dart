import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lumen_studio/app/models/client.dart';
import 'package:lumen_studio/app/models/studio_event.dart';
import 'package:lumen_studio/app/providers/auth_provider.dart';
import 'package:lumen_studio/app/providers/events_provider.dart';
import 'package:lumen_studio/app/providers/invoices_provider.dart';
import 'package:lumen_studio/app/providers/notifications_provider.dart';
import 'package:lumen_studio/app/providers/theme_provider.dart';
import 'package:lumen_studio/app/screens/clients/client_details_screen.dart';
import 'package:lumen_studio/app/screens/clients/clients_screen.dart';
import 'package:lumen_studio/app/screens/home/home_screen.dart';
import 'package:lumen_studio/app/screens/shell/app_shell.dart';
import 'package:lumen_studio/app/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Client Model & StudioEvent Core Logic', () {
    test('Client model serializes and copies correctly', () {
      const client = Client(
        id: 'c1',
        name: 'Aanya Sharma',
        phone: '+91 98765 43210',
        email: 'aanya@example.com',
        address: 'Mumbai',
        notes: 'Bride',
      );

      final json = client.toJson();
      final fromJson = Client.fromJson(json);

      expect(fromJson.id, 'c1');
      expect(fromJson.name, 'Aanya Sharma');
      expect(fromJson.phone, '+91 98765 43210');
      expect(fromJson.email, 'aanya@example.com');
      expect(fromJson.address, 'Mumbai');
      expect(fromJson.notes, 'Bride');

      final updated = client.copyWith(name: 'Aanya & Rohan');
      expect(updated.name, 'Aanya & Rohan');
      expect(updated.phone, client.phone);
    });

    test('Calculates event amountReceived dynamically from payments', () {
      final now = DateTime.now();
      final event = StudioEvent(
        id: 'test-1',
        clientId: 'cli-1',
        title: 'Test Wedding',
        clientName: 'Test Client',
        eventType: 'Wedding',
        startsAt: DateTime(2026, 8, 12),
        location: 'Lotus Pavilion',
        status: EventStatus.upcoming,
        totalAmount: 120000,
        payments: [
          PaymentRecord(
            id: 'p1',
            title: 'Advance',
            amount: 50000,
            paidAt: now,
            method: PaymentMethod.upi,
            reference: 'UPI123',
            proof: 'receipt.png',
          ),
          PaymentRecord(
            id: 'p2',
            title: 'Mid milestone',
            amount: 30000,
            paidAt: now,
            method: PaymentMethod.bankTransfer,
          ),
        ],
        expenses: [
          ExpenseRecord(
            id: 'e1',
            title: 'Photographer',
            amount: 15000,
            category: 'Crew',
            incurredAt: now,
          ),
        ],
      );

      // Amount received = 50000 + 30000 = 80000
      expect(event.amountReceived, 80000);
      // Remaining = 120000 - 80000 = 40000
      expect(event.remainingAmount, 40000);
      // Net profit = 80000 - 15000 = 65000
      expect(event.netProfit, 65000);
      // Proof
      expect(event.payments[0].hasProof, isTrue);
      expect(event.payments[1].hasProof, isFalse);
    });

    test('EventsProvider manages Clients and multi-event client aggregations', () {
      final provider = EventsProvider();

      // Verify seed clients exist
      expect(provider.clients.length, greaterThanOrEqualTo(5));

      // Check Meera Kapoor has multiple events (upcoming & past)
      final meeraEvents = provider.getEventsForClient('cli-2', clientName: 'Meera Kapoor');
      expect(meeraEvents.length, 2);

      // Total Value across Meera's events = 40000 + 35000 = 75000
      expect(provider.getClientTotalValue('cli-2'), 75000);
      // Total Received across Meera's events = 25000 + 35000 = 60000
      expect(provider.getClientTotalReceived('cli-2'), 60000);
      // Total Remaining across Meera's events = 15000 + 0 = 15000
      expect(provider.getClientTotalRemaining('cli-2'), 15000);

      // Add payment to Meera's event
      provider.addPayment(
        'evt-up-2',
        PaymentRecord(
          id: 'pay-new',
          title: 'Settlement',
          amount: 15000,
          paidAt: DateTime.now(),
          method: PaymentMethod.upi,
        ),
      );

      // Now Meera should have remaining = 0
      expect(provider.getClientTotalRemaining('cli-2'), 0);
    });
  });

  group('ClientsScreen UI & Flow Tests', () {
    testWidgets('ClientsScreen displays client list, search bar, and filter chips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = EventsProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: ClientsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('Aanya Sharma'), findsOneWidget);
      expect(find.text('Meera Kapoor'), findsOneWidget);
      expect(find.text('Northwind Atelier'), findsOneWidget);
      expect(find.text('The Iyer Family'), findsOneWidget);

      // Verify filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Payment Due'), findsOneWidget);

      // Test Search by phone
      await tester.enterText(find.byType(TextField), '98234');
      await tester.pumpAndSettle();

      expect(find.text('Meera Kapoor'), findsOneWidget);
      expect(find.text('Northwind Atelier'), findsNothing);
    });

    testWidgets('ClientDetailsScreen displays contact info, events, and opens EventDetailsScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = EventsProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const ClientDetailsScreen(clientId: 'cli-2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Contact info
      expect(find.text('Meera Kapoor'), findsWidgets);
      expect(find.text('+91 98234 56789'), findsOneWidget);
      expect(find.text('meera.kapoor@example.com'), findsOneWidget);

      // Financial Summary (Value, Received, Remaining - NO profit)
      expect(find.text('Financial Summary'), findsOneWidget);
      expect(find.text('Total Event Value'), findsOneWidget);
      expect(find.text('Total Received'), findsOneWidget);
      expect(find.text('Total Remaining'), findsOneWidget);
      expect(find.text('Net Profit'), findsNothing); // Crucial: No profit on client screen

      // Events belonging to client
      expect(find.text('Client Events'), findsOneWidget);
      expect(find.text('Maternity Session — Meera'), findsOneWidget);
      expect(find.text('Meera — Maternity Studio Shoot'), findsOneWidget);

      // Payment History & View Proof
      expect(find.text('Payment History'), findsOneWidget);
      expect(find.text('View Proof'), findsWidgets);

      // Tap on an event -> navigates to EventDetailsScreen
      await tester.tap(find.text('Maternity Session — Meera'));
      await tester.pumpAndSettle();

      // Verify EventDetailsScreen opened
      expect(find.text('Event Financials'), findsOneWidget);
      expect(find.text('Work Progress'), findsOneWidget);
    });
  });

  group('HomeScreen & Event Details UI', () {
    testWidgets('Home screen displays Upcoming Events, Add Event button and Past Events',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => EventsProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upcoming Events'), findsOneWidget);
      expect(find.text('+ Add Event'), findsOneWidget);
      expect(find.text('Past Events'), findsOneWidget);
      expect(find.text('View all →'), findsNWidgets(2));
    });

    testWidgets('AppShell renders and navigates between tabs without exceptions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = AuthProvider();
      final events = EventsProvider();
      final notifs = NotificationsProvider();
      notifs.syncEvents(events);
      final invoices = InvoicesProvider();
      invoices.syncAuth(auth);

      tester.view.physicalSize = const Size(420, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: events),
            ChangeNotifierProvider.value(value: notifs),
            ChangeNotifierProvider.value(value: invoices),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const AppShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Calendar'), findsWidgets);

      await tester.tap(find.text('Calendar').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Booked sessions & shoot schedule'), findsOneWidget);

      // Tap Invoices
      await tester.tap(find.text('Invoices').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Clients
      await tester.tap(find.text('Clients').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      notifs.dispose();
    });
  });
}

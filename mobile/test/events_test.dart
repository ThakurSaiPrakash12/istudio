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
import 'package:lumen_studio/app/widgets/monthly_financial_summary_sheet.dart';
import 'package:provider/provider.dart';

EventsProvider _populatedProvider() {
  final provider = EventsProvider();
  provider.addClient(
    const Client(
      id: 'cli-1',
      name: 'Aanya Sharma',
      phone: '+91 98765 43210',
      email: 'aanya.sharma@example.com',
    ),
  );
  provider.addClient(
    const Client(
      id: 'cli-2',
      name: 'Meera Kapoor',
      phone: '+91 98234 56789',
      email: 'meera.kapoor@example.com',
    ),
  );
  provider.addClient(
    const Client(
      id: 'cli-3',
      name: 'Northwind Atelier',
      phone: '+91 91234 56780',
      email: 'campaigns@northwindatelier.com',
    ),
  );
  provider.addClient(
    const Client(
      id: 'cli-4',
      name: 'The Iyer Family',
      phone: '+91 99887 76655',
      email: 'arjun.iyer@example.com',
    ),
  );
  provider.addClient(
    const Client(
      id: 'cli-5',
      name: 'Aarav & Priya',
      phone: '+91 98111 22334',
      email: 'aarav.priya@example.com',
    ),
  );
  final now = DateTime.now();
  provider.addEvent(
    StudioEvent(
      id: 'evt-up-2',
      clientId: 'cli-2',
      title: 'Maternity Session — Meera',
      clientName: 'Meera Kapoor',
      eventType: 'Maternity',
      startsAt: now.add(const Duration(days: 5)),
      location: 'Studio Floor B',
      status: EventStatus.upcoming,
      totalAmount: 40000,
      payments: [
        PaymentRecord(
          id: 'p-103',
          title: 'Advance Deposit',
          amount: 25000,
          paidAt: now,
          proof: 'receipt.png',
        ),
      ],
    ),
  );
  provider.addEvent(
    StudioEvent(
      id: 'evt-past-2',
      clientId: 'cli-2',
      title: 'Meera — Maternity Studio Shoot',
      clientName: 'Meera Kapoor',
      eventType: 'Maternity',
      startsAt: now.subtract(const Duration(days: 20)),
      location: 'Studio Floor B',
      status: EventStatus.completed,
      totalAmount: 35000,
      payments: [
        PaymentRecord(
          id: 'p-302',
          title: 'Final Settlement',
          amount: 35000,
          paidAt: now,
          proof: 'receipt-final.png',
        ),
      ],
    ),
  );
  return provider;
}

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

    test(
      'EventsProvider manages Clients and multi-event client aggregations',
      () {
        final provider = _populatedProvider();

        // Verify seed clients exist
        expect(provider.clients.length, greaterThanOrEqualTo(5));

        // Check Meera Kapoor has multiple events (upcoming & past)
        final meeraEvents = provider.getEventsForClient(
          'cli-2',
          clientName: 'Meera Kapoor',
        );
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
      },
    );
  });

  group('ClientsScreen UI & Flow Tests', () {
    testWidgets(
      'ClientsScreen displays client list, search bar, and filter chips',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final provider = _populatedProvider();

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
        expect(find.text('Information'), findsWidgets);
        expect(find.text('Coming Up'), findsWidgets);
        expect(find.text('Completed'), findsWidgets);
        expect(find.text('Due'), findsOneWidget);

        // Test Search by phone
        await tester.enterText(find.byType(TextField), '98234');
        await tester.pumpAndSettle();

        expect(find.text('Meera Kapoor'), findsOneWidget);
        expect(find.text('Northwind Atelier'), findsNothing);
      },
    );

    testWidgets(
      'ClientDetailsScreen displays contact info, events, and opens EventDetailsScreen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final provider = _populatedProvider();

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
        expect(
          find.text('Net Profit'),
          findsNothing,
        ); // Crucial: No profit on client screen

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
        expect(find.text('Payment Details'), findsOneWidget);
        expect(find.text('Work Progress'), findsOneWidget);
      },
    );
  });

  group('HomeScreen & Event Details UI', () {
    testWidgets(
      'Home screen displays Upcoming Events, Add Event button and Past Events',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => _populatedProvider()),
              ChangeNotifierProvider(create: (_) => InvoicesProvider()),
              ChangeNotifierProvider(create: (_) => NotificationsProvider()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: HomeScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Coming Up'), findsOneWidget);
        expect(find.text('Done'), findsWidgets);
        expect(find.text('See all'), findsNWidgets(2));
      },
    );

    testWidgets(
      'AppShell renders and navigates between tabs without exceptions',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final auth = AuthProvider();
        final events = _populatedProvider();
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
            child: MaterialApp(theme: AppTheme.dark, home: const AppShell()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Calendar'), findsWidgets);

        await tester.tap(find.text('Calendar').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Booked sessions'), findsOneWidget);

        // Tap Receipt
        await tester.tap(find.text('Receipt').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Clients
        await tester.tap(find.text('Clients').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        notifs.dispose();
      },
    );

    testWidgets(
      'MonthlyFinancialSummarySheet renders monthly stats and event breakdown',
      (WidgetTester tester) async {
        final notifs = NotificationsProvider();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => _populatedProvider()),
              ChangeNotifierProvider(create: (_) => notifs),
              ChangeNotifierProvider(create: (_) => AuthProvider()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => MonthlyFinancialSummarySheet.show(
                      context,
                      initialMonth: DateTime(2026, 8),
                    ),
                    child: const Text('Open Summary'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Summary'));
        await tester.pumpAndSettle();

        expect(find.text('Monthly Earnings'), findsOneWidget);
        expect(find.text('August 2026'), findsOneWidget);
        expect(find.text('Total Booked'), findsOneWidget);
        expect(find.text('Received'), findsOneWidget);
        expect(find.text('Expenses'), findsOneWidget);
        expect(find.text('Profit (Net)'), findsOneWidget);

        notifs.dispose();
      },
    );

    test('EventsProvider properly categorizes client status and applies 15-day TTL', () {
      final provider = EventsProvider();
      final now = DateTime.now();

      // Recent inquiry (< 15 days)
      provider.addClient(
        Client(
          id: 'info-recent',
          name: 'Recent Inquiry',
          phone: '1111111111',
          email: 'recent@example.com',
          status: ClientStatus.information,
          createdAt: now.subtract(const Duration(hours: 24)),
        ),
      );

      // Expired inquiry (>= 15 days -> auto marked as notResponded)
      provider.addClient(
        Client(
          id: 'info-expired',
          name: 'Expired Inquiry',
          phone: '2222222222',
          email: 'expired@example.com',
          status: ClientStatus.information,
          createdAt: now.subtract(const Duration(days: 16)),
        ),
      );

      // Coming Up client
      provider.addClient(
        const Client(
          id: 'client-comingup',
          name: 'Coming Up Client',
          phone: '3333333333',
          email: 'comingup@example.com',
          status: ClientStatus.comingUp,
        ),
      );

      // Completed client
      provider.addClient(
        const Client(
          id: 'client-completed',
          name: 'Completed Client',
          phone: '4444444444',
          email: 'completed@example.com',
          status: ClientStatus.completed,
        ),
      );

      expect(provider.recentInformationClients.length, 1);
      expect(provider.recentInformationClients.first.id, 'info-recent');
      expect(provider.notRespondedClients.length, 1);
      expect(provider.notRespondedClients.first.id, 'info-expired');
      expect(provider.comingUpClients.length, 1);
      expect(provider.completedClients.length, 1);
    });

    testWidgets(
      'HomeScreen shows Information Inquiries box only when recent inquiry clients exist',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final provider = EventsProvider();
        final now = DateTime.now();

        // 1. Without any inquiry clients, box should not exist
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider(create: (_) => InvoicesProvider()),
              ChangeNotifierProvider(create: (_) => NotificationsProvider()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: HomeScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Information Inquiries'), findsNothing);

        // 2. Add an expired inquiry (>= 15 days) -> marked notResponded & does not show
        provider.addClient(
          Client(
            id: 'expired-1',
            name: 'Old Lead',
            phone: '5555555555',
            email: 'oldlead@example.com',
            status: ClientStatus.information,
            createdAt: now.subtract(const Duration(days: 16)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Information Inquiries'), findsNothing);

        // 3. Add a fresh inquiry (< 15 days) -> box appears with Call action!
        provider.addClient(
          Client(
            id: 'fresh-1',
            name: 'Fresh Lead',
            phone: '9999999999',
            email: 'freshlead@example.com',
            status: ClientStatus.information,
            createdAt: now.subtract(const Duration(hours: 5)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Information Inquiries'), findsOneWidget);
        expect(find.text('Fresh Lead'), findsOneWidget);
        expect(find.text('Recent client inquiries (active 15 days)'), findsOneWidget);
        expect(find.text('Call'), findsOneWidget);
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/models/invoice.dart';
import 'package:lumen_studio/app/models/studio_event.dart';
import 'package:lumen_studio/app/services/invoice_pdf_service.dart';
import 'package:lumen_studio/app/widgets/event_countdown_banner.dart';
import 'package:lumen_studio/app/widgets/studio_button.dart';
import 'package:lumen_studio/app/widgets/studio_card.dart';
import 'package:lumen_studio/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Kinetic Fluidity & Render Performance', () {
    test('FluidScrollBehavior provides 120Hz bouncing spring physics', () {
      const behavior = FluidScrollBehavior();
      final context = _MockBuildContext();
      final physics = behavior.getScrollPhysics(context);
      
      expect(physics, isA<BouncingScrollPhysics>());
      expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('StudioButton has micro-scale spring feedback', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudioButton(
                label: 'Test Button',
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
      expect(find.byType(AnimatedScale), findsOneWidget);

      await tester.tap(find.text('Test Button'));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });

    testWidgets('StudioCard wraps content in isolated RepaintBoundary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudioCard(
                child: Text('Card Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      // Ensure RepaintBoundary is present around card content
      expect(find.descendant(of: find.byType(StudioCard), matching: find.byType(RepaintBoundary)), findsWidgets);
    });

    testWidgets('EventCountdownBanner is isolated with RepaintBoundary', (tester) async {
      final event = StudioEvent(
        id: 'test-event-1',
        title: 'Destination Wedding',
        clientName: 'Rahul & Priya',
        eventType: 'Wedding',
        location: 'Udaipur Palace',
        startsAt: DateTime.now().add(const Duration(days: 2, hours: 4)),
        totalAmount: 150000,
        status: EventStatus.upcoming,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCountdownBanner(
              event: event,
            ),
          ),
        ),
      );

      expect(find.text('Destination Wedding'), findsOneWidget);
      expect(find.descendant(of: find.byType(EventCountdownBanner), matching: find.byType(RepaintBoundary)), findsWidgets);
    });

    test('InvoicePdfService builds PDF bytes without throwing', () async {
      final invoice = Invoice(
        id: 'inv-test-1',
        number: 'INV-3001',
        eventName: 'Haldi Shoot',
        contactName: 'Sneha Patel',
        phone: '9876543210',
        address: 'Jaipur',
        issuedOn: DateTime(2026, 9, 1),
        dueDate: DateTime(2026, 10, 1),
        upiId: 'studio@upi',
        amountReceived: 15000,
        deliverables: const [
          InvoiceDeliverable(id: 'd1', name: 'Raw Photos', cost: 25000),
          InvoiceDeliverable(id: 'd2', name: 'Reels Cut', cost: 10000),
        ],
      );

      final bytes = await InvoicePdfService.buildBytes(invoice: invoice);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });
}

class _MockBuildContext extends Fake implements BuildContext {}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/customer_app_shell.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('captures the five customer interfaces with synthetic data',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fontLoader = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    await fontLoader.load();
    final iconFontLoader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load(
        'fonts/MaterialIcons-Regular.otf',
      ));
    await iconFontLoader.load();

    final state = _demoState();
    addTearDown(state.dispose);
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RepaintBoundary(
        key: boundaryKey,
        child: CustomerAppShell(
          isDark: false,
          onToggleTheme: () {},
          customerId: 'customer-demo',
          verifiedSession: true,
          customerName: 'حساب تجريبي',
          state: state,
          merchantNames: const {
            'merchant-demo-1': 'متجر السعادة',
            'merchant-demo-2': 'متجر الروضة',
          },
          publicStores: const [
            CustomerPublicStore(
              merchantId: 'merchant-demo-1',
              name: 'متجر السعادة',
              governorate: 'أمانة العاصمة',
              market: 'سوق شميلة',
              isOpen: true,
              acceptsBookings: true,
              description: 'واجهة توضيحية لمتجر يستقبل الحجوزات.',
            ),
            CustomerPublicStore(
              merchantId: 'merchant-demo-2',
              name: 'متجر الروضة',
              governorate: 'صنعاء',
              market: 'سوق الروضة',
              isOpen: false,
              acceptsBookings: true,
              description: 'قد يستقبل المتجر الحجوزات حتى وهو مغلق.',
            ),
          ],
          studioPosts: [
            CustomerStudioPost(
              id: 'post-demo',
              merchantId: 'merchant-demo-1',
              merchantName: 'متجر السعادة',
              caption: 'منشور تجريبي من استوديو المتاجر.',
              createdAt: DateTime(2026, 11, 17),
            ),
          ],
          bookings: [
            CustomerBooking(
              id: 'booking-demo',
              merchantName: 'متجر السعادة',
              description: 'حجز توضيحي — باقة واحدة',
              createdAt: DateTime(2026, 11, 17),
              status: 'بانتظار التاجر',
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final screenshots = Directory('build/customer-ui-screenshots');
    screenshots.createSync(recursive: true);

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final data = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          return await image.toByteData(format: ui.ImageByteFormat.png);
        } finally {
          image.dispose();
        }
      });
      if (data == null) throw StateError('Failed to encode $name screenshot.');
      File('${screenshots.path}/$name.png')
          .writeAsBytesSync(data.buffer.asUint8List());
    }

    const names = [
      'home',
      'movements',
      'studio',
      'merchants',
      'discover',
    ];
    for (var index = 0; index < names.length; index++) {
      if (index > 0) {
        await tester.tap(find.byKey(Key('customer_nav_$index')));
        await tester.pumpAndSettle();
      }
      await capture(names[index]);
    }

    for (final name in names) {
      expect(File('${screenshots.path}/$name.png').existsSync(), isTrue);
    }
  });
}

AppState _demoState() {
  final state = AppState();
  final now = DateTime(2026, 11, 17, 10);
  state.addCustomer(CustomerModel(
    id: 'customer-demo',
    name: 'عميل توضيحي',
    phone: '777000111',
    primaryCurrency: CurrencyCode.yer,
    createdAt: now,
    updatedAt: now,
  ));
  state.requestRelationship(
    id: 'relationship-demo-1',
    merchantId: 'merchant-demo-1',
    customerId: 'customer-demo',
    actorId: 'merchant-demo-1',
    actorRole: ParticipantRole.merchant,
    createdAt: now,
  );
  state.decideRelationship(
    relationshipId: 'relationship-demo-1',
    actorId: 'customer-demo',
    actorRole: ParticipantRole.customer,
    decision: ApprovalDecision.approved,
    decidedAt: now.add(const Duration(minutes: 1)),
  );
  state.requestRelationship(
    id: 'relationship-demo-2',
    merchantId: 'merchant-demo-2',
    customerId: 'customer-demo',
    actorId: 'merchant-demo-2',
    actorRole: ParticipantRole.merchant,
    createdAt: now,
  );

  MovementModel movement({
    required String id,
    required String relationshipId,
    required String merchantId,
    required String amount,
    required CurrencyCode currency,
    required MovementType type,
    required MovementStatus status,
  }) {
    return MovementModel(
      id: id,
      relationshipId: relationshipId,
      customerId: 'customer-demo',
      merchantId: merchantId,
      amount: Decimal.parse(amount),
      currency: currency,
      type: type,
      createdBy: merchantId,
      createdByRole: ParticipantRole.merchant,
      createdAt: now,
      description: type == MovementType.debt ? 'مشتريات توضيحية' : 'دفعة توضيحية',
      approvals: [
        ApprovalRecord(
          actorId: merchantId,
          role: ParticipantRole.merchant,
          decision: ApprovalDecision.declared,
          decidedAt: now,
        ),
        if (status != MovementStatus.pending)
          ApprovalRecord(
            actorId: 'customer-demo',
            role: ParticipantRole.customer,
            decision: status == MovementStatus.approved
                ? ApprovalDecision.approved
                : ApprovalDecision.rejected,
            decidedAt: now.add(const Duration(minutes: 2)),
          ),
      ],
    );
  }

  // This is a synthetic server snapshot for screenshots, not persisted data.
  state.movements.value = [
    movement(
      id: 'movement-demo-yer-debt',
      relationshipId: 'relationship-demo-1',
      merchantId: 'merchant-demo-1',
      amount: '100000',
      currency: CurrencyCode.yer,
      type: MovementType.debt,
      status: MovementStatus.approved,
    ),
    movement(
      id: 'movement-demo-yer-payment',
      relationshipId: 'relationship-demo-1',
      merchantId: 'merchant-demo-1',
      amount: '25000',
      currency: CurrencyCode.yer,
      type: MovementType.payment,
      status: MovementStatus.approved,
    ),
    movement(
      id: 'movement-demo-sar-debt',
      relationshipId: 'relationship-demo-1',
      merchantId: 'merchant-demo-1',
      amount: '450',
      currency: CurrencyCode.sar,
      type: MovementType.debt,
      status: MovementStatus.approved,
    ),
    movement(
      id: 'movement-demo-usd-debt',
      relationshipId: 'relationship-demo-1',
      merchantId: 'merchant-demo-1',
      amount: '20',
      currency: CurrencyCode.usd,
      type: MovementType.debt,
      status: MovementStatus.approved,
    ),
    movement(
      id: 'movement-demo-yer-pending',
      relationshipId: 'relationship-demo-1',
      merchantId: 'merchant-demo-1',
      amount: '12000',
      currency: CurrencyCode.yer,
      type: MovementType.debt,
      status: MovementStatus.pending,
    ),
    movement(
      id: 'movement-demo-prior-claim',
      relationshipId: 'relationship-demo-2',
      merchantId: 'merchant-demo-2',
      amount: '3500',
      currency: CurrencyCode.yer,
      type: MovementType.debt,
      status: MovementStatus.pending,
    ),
  ];
  return state;
}

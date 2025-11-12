import 'package:flutter_test/flutter_test.dart';

import 'package:vendeme_time/vendeme_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VendemeTime.instance.reset();
    initializeVendemeChileDefaults();
  });

  test('converts UTC instants to Chile local time using overrides', () {
    final DateTime winterUtc = DateTime.utc(2024, 6, 1, 12);
    final DateTime winterLocal = VendemeTime.instance.convertUtcToLocal(
      winterUtc,
    );
    expect(winterLocal, DateTime.utc(2024, 6, 1, 8)); // UTC-4 during winter.

    final DateTime summerUtc = DateTime.utc(2024, 12, 1, 12);
    final DateTime summerLocal = VendemeTime.instance.convertUtcToLocal(
      summerUtc,
    );
    expect(summerLocal, DateTime.utc(2024, 12, 1, 9)); // UTC-3 during summer.
  });

  test(
    'falls back to default offset when instant is outside configured spans',
    () {
      final DateTime legacyUtc = DateTime.utc(2023, 1, 1, 12);
      final DateTime local = VendemeTime.instance.convertUtcToLocal(legacyUtc);
      expect(local, DateTime.utc(2023, 1, 1, 9));
    },
  );

  test('converts local instants back to UTC', () {
    final DateTime local = DateTime(
      2024,
      12,
      1,
      9,
    ); // Already in Chile summer time.
    final DateTime utc = VendemeTime.instance.convertLocalToUtc(local);
    expect(utc, DateTime.utc(2024, 12, 1, 12));
  });

  test('registers zones from decoded maps', () {
    VendemeTime.instance.reset();
    VendemeTime.instance.registerZoneFromMap(<String, dynamic>{
      'id': 'Custom/Fixed',
      'fallbackMinutes': 180,
      'periods': <Map<String, dynamic>>[
        <String, dynamic>{
          'start': '2020-01-01T00:00:00Z',
          'offsetMinutes': 180,
        },
      ],
    }, setAsDefault: true);

    final DateTime utc = DateTime.utc(2024, 1, 1, 0, 0);
    expect(
      VendemeTime.instance.convertUtcToLocal(utc),
      DateTime.utc(2024, 1, 1, 3),
    );
  });

  test('registers zones from packaged asset', () async {
    VendemeTime.instance.reset();
    await initializeVendemeTime();

    final DateTime utc = DateTime.utc(2024, 12, 1, 12);
    expect(
      VendemeTime.instance.convertUtcToLocal(utc),
      DateTime.utc(2024, 12, 1, 9),
    );
  });
}

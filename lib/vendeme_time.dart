import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'src/chile_rule.dart';
export 'src/chile_rule.dart' show buildChileTimeZone;

/// Central entry point for vendeme time zone overrides.
///
/// This class keeps a simple in-memory time zone database so that devices with
/// outdated Android tzdata (common on Android 6) can still produce the correct
/// local time. Clients feed the UTC instant obtained from `DateTime.toUtc()`
/// and get back a local `DateTime` using the rules registered here.
class VendemeTime {
  VendemeTime._();

  /// Singleton instance used by all helpers.
  static final VendemeTime instance = VendemeTime._();

  final Map<String, VendemeTimeZone> _zones = <String, VendemeTimeZone>{};
  String? _defaultZoneId;

  /// Registers a time zone definition.
  void registerZone(VendemeTimeZone zone, {bool setAsDefault = false}) {
    _zones[zone.id] = zone;
    if (setAsDefault || _defaultZoneId == null) {
      _defaultZoneId = zone.id;
    }
  }

  /// Registers a zone from a decoded map (useful for tests or local assets).
  void registerZoneFromMap(
    Map<String, dynamic> data, {
    bool setAsDefault = false,
  }) {
    registerZone(VendemeTimeZone.fromMap(data), setAsDefault: setAsDefault);
  }

  /// Registers a zone from a JSON encoded string.
  void registerZoneFromJson(String jsonString, {bool setAsDefault = false}) {
    final dynamic decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected a JSON object for zone definition.');
    }
    registerZoneFromMap(decoded, setAsDefault: setAsDefault);
  }

  /// Loads and registers a zone definition stored as an asset.
  Future<void> registerZoneFromAsset(
    String assetPath, {
    AssetBundle? bundle,
    bool setAsDefault = false,
  }) async {
    final AssetBundle effectiveBundle = bundle ?? rootBundle;
    final String raw = await effectiveBundle.loadString(assetPath);
    registerZoneFromJson(raw, setAsDefault: setAsDefault);
  }

  /// Clears the registered zones. Primarily intended for tests.
  void reset() {
    _zones.clear();
    _defaultZoneId = null;
  }

  /// Picks the zone that should be used, falling back to the default if needed.
  VendemeTimeZone _resolveZone(String? zoneId) {
    final String? id = zoneId ?? _defaultZoneId;
    if (id == null) {
      throw TimeZoneNotFoundException('No default time zone configured.');
    }
    final VendemeTimeZone? zone = _zones[id];
    if (zone == null) {
      throw TimeZoneNotFoundException('Time zone "$id" is not registered.');
    }
    return zone;
  }

  /// Converts a UTC instant into local time using the configured zone rules.
  DateTime convertUtcToLocal(DateTime utc, {String? zoneId}) {
    if (!utc.isUtc) {
      throw ArgumentError('Expected a UTC DateTime. Call toUtc() first.');
    }
    final VendemeTimeZone zone = _resolveZone(zoneId);
    final Duration offset = zone.offsetFor(utc);
    return utc.add(offset);
  }

  /// Converts a local instant back to UTC using the configured zone rules.
  DateTime convertLocalToUtc(DateTime local, {String? zoneId}) {
    if (local.isUtc) {
      throw ArgumentError('Expected a local DateTime, not UTC.');
    }
    final VendemeTimeZone zone = _resolveZone(zoneId);
    final DateTime skeletonUtc = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
    for (final VendemeTimeZoneSpan span in zone.spans) {
      final DateTime candidate = skeletonUtc.subtract(span.offset);
      if (span.contains(candidate)) {
        return candidate;
      }
    }
    return skeletonUtc.subtract(zone.fallbackOffset);
  }

  /// Returns the current local time using the configured zone rules.
  ///
  /// By default it reads the device clock via `DateTime.now()`. If your app
  /// already has a trusted UTC source (e.g. NTP via `FlutterKronosPlus`), pass
  /// it through [utcNow] so the conversion uses it instead of the system clock.
  DateTime localNow({DateTime? utcNow, String? zoneId}) {
    final DateTime utc = (utcNow ?? DateTime.now()).toUtc();
    return convertUtcToLocal(utc, zoneId: zoneId);
  }

  /// Returns the offset used for the given instant.
  Duration offsetFor(DateTime utc, {String? zoneId}) {
    if (!utc.isUtc) {
      throw ArgumentError('Expected a UTC DateTime.');
    }
    final VendemeTimeZone zone = _resolveZone(zoneId);
    return zone.offsetFor(utc);
  }
}

/// Holds all transitions for a single time zone.
class VendemeTimeZone {
  VendemeTimeZone({
    required this.id,
    required List<VendemeTimeZoneSpan> spans,
    Duration? fallbackOffset,
  }) : _spans = List<VendemeTimeZoneSpan>.unmodifiable(
         (List<VendemeTimeZoneSpan>.from(spans))..sort(
           (VendemeTimeZoneSpan a, VendemeTimeZoneSpan b) =>
               a.start.compareTo(b.start),
         ),
       ),
       fallbackOffset =
           fallbackOffset ??
           (spans.isNotEmpty ? spans.last.offset : const Duration()) {
    if (_spans.isEmpty) {
      throw ArgumentError('A time zone requires at least one span.');
    }
  }

  final String id;
  final List<VendemeTimeZoneSpan> _spans;
  final Duration fallbackOffset;

  Iterable<VendemeTimeZoneSpan> get spans => _spans;

  /// Finds the offset that applies to the provided UTC instant.
  Duration offsetFor(DateTime utc) {
    if (!utc.isUtc) {
      throw ArgumentError('offsetFor expects UTC instants.');
    }
    for (final VendemeTimeZoneSpan span in _spans) {
      if (span.contains(utc)) {
        return span.offset;
      }
    }
    // There is no matching span, use the fallback as a conservative default.
    return fallbackOffset;
  }

  /// Parses a zone definition from a decoded JSON map.
  factory VendemeTimeZone.fromMap(Map<String, dynamic> map) {
    final String? id = map['id'] as String?;
    if (id == null || id.isEmpty) {
      throw FormatException('Time zone map requires an "id" string.');
    }
    final dynamic periodsRaw = map['periods'];
    if (periodsRaw is! List) {
      throw FormatException('Time zone "$id" must contain a periods array.');
    }
    final List<VendemeTimeZoneSpan> spans = periodsRaw.map((dynamic period) {
      if (period is! Map<String, dynamic>) {
        throw FormatException('Invalid period entry in zone "$id".');
      }
      return VendemeTimeZoneSpan.fromMap(period);
    }).toList();

    final int? fallbackMinutes = map['fallbackMinutes'] as int?;
    return VendemeTimeZone(
      id: id,
      spans: spans,
      fallbackOffset: fallbackMinutes != null
          ? Duration(minutes: fallbackMinutes)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'fallbackMinutes': fallbackOffset.inMinutes,
      'periods': _spans
          .map((VendemeTimeZoneSpan span) => span.toMap())
          .toList(),
    };
  }
}

/// Represents a zone span where the offset stays constant.
class VendemeTimeZoneSpan {
  VendemeTimeZoneSpan({
    required DateTime start,
    DateTime? end,
    required this.offset,
  }) : start = start.toUtc(),
       end = end?.toUtc() {
    if (!this.start.isUtc) {
      throw ArgumentError('start must be UTC.');
    }
    if (this.end != null && !this.end!.isUtc) {
      throw ArgumentError('end must be UTC.');
    }
  }

  final DateTime start;
  final DateTime? end;
  final Duration offset;

  bool contains(DateTime instant) {
    if (!instant.isUtc) {
      throw ArgumentError('contains expects UTC instants.');
    }
    final bool afterStart = !instant.isBefore(start);
    final bool beforeEnd = end == null || instant.isBefore(end!);
    return afterStart && beforeEnd;
  }

  factory VendemeTimeZoneSpan.fromMap(Map<String, dynamic> map) {
    final String? startRaw = map['start'] as String?;
    if (startRaw == null) {
      throw FormatException('Each period requires a "start" timestamp.');
    }
    final DateTime start = DateTime.parse(startRaw).toUtc();

    final String? endRaw = map['end'] as String?;
    final DateTime? end = endRaw != null
        ? DateTime.parse(endRaw).toUtc()
        : null;

    final int? offsetMinutes = map['offsetMinutes'] as int?;
    if (offsetMinutes == null) {
      throw FormatException('Each period requires "offsetMinutes".');
    }

    return VendemeTimeZoneSpan(
      start: start,
      end: end,
      offset: Duration(minutes: offsetMinutes),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'offsetMinutes': offset.inMinutes,
    };
  }
}

/// Thrown when a requested time zone is not registered.
class TimeZoneNotFoundException implements Exception {
  TimeZoneNotFoundException(this.message);

  final String message;

  @override
  String toString() => 'TimeZoneNotFoundException: $message';
}

/// Chilean time zone configuration generated from the IANA rule.
final Map<String, dynamic> kVendemeChileTimeZone = buildChileTimeZone();

/// Asset path for the packaged Chilean time zone definition.
const String kVendemeChileTimeZoneAsset =
    'packages/vendeme_time/assets/timezones/chile.json';

/// List of all bundled time zone assets provided by this package.
const List<String> kVendemeBundledTimeZoneAssets = <String>[
  kVendemeChileTimeZoneAsset,
];

/// Initializes Vendeme Time by loading every bundled time zone asset.
Future<void> initializeVendemeTime({AssetBundle? bundle}) async {
  for (int index = 0; index < kVendemeBundledTimeZoneAssets.length; index++) {
    await VendemeTime.instance.registerZoneFromAsset(
      kVendemeBundledTimeZoneAssets[index],
      bundle: bundle,
    );
  }
}

/// Convenience bootstrapper that registers the bundled Chile zone as default.
void initializeVendemeChileDefaults() {
  VendemeTime.instance.registerZoneFromMap(
    kVendemeChileTimeZone,
    setAsDefault: true,
  );
}

/// Asynchronous bootstrapper that reads the Chile zone from the JSON asset.
Future<void> initializeVendemeChileDefaultsFromAsset({
  AssetBundle? bundle,
}) async {
  await VendemeTime.instance.registerZoneFromAsset(
    kVendemeChileTimeZoneAsset,
    bundle: bundle,
    setAsDefault: true,
  );
}

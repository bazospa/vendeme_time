Vendeme Time keeps Flutter apps running on legacy Android builds in sync with current timezone rules. The plugin ships a lightweight override engine that applies hand curated tz data (for example, the recent changes in Chile) on top of the system clock, so calls to `DateTime.toLocal()` stay correct even when the OS tzdb is outdated.

## Highlights
- Override timezone offsets on devices with stale tzdata (Android 6 and similar).
- Register rules programmatically or load them from JSON assets bundled with your app.
- Provide fallbacks for instants that fall outside the known transitions.
- Simple API that mirrors `DateTime` conversions (`utc -> local`, `local -> utc`, offset lookup).

## Installation
1. Add the package to your `pubspec.yaml` dependencies.
2. Run `flutter pub get`.

## Basic Usage
Initialize Vendeme Time during app start up:

```dart
import 'package:vendeme_time/vendeme_time.dart';

Future<void> bootstrapTimeZones() async {
	await initializeVendemeTime();
}

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();
	await bootstrapTimeZones();
	runApp(const MyApp());
}
```

Convert instants using the override engine instead of the platform tzdb:

```dart
final DateTime nowUtc = DateTime.now().toUtc();
final DateTime local = VendemeTime.instance.convertUtcToLocal(nowUtc);

// To go the other way:
final DateTime backToUtc = VendemeTime.instance.convertLocalToUtc(local);
```

Calling `initializeVendemeTime()` loads every timezone JSON shipped within the package (currently Chile). You can register extra regions by adding your own asset files and calling `registerZoneFromAsset` as shown below.

You can register additional zones from your app bundle and request them explicitly using their ID:

```dart
await VendemeTime.instance.registerZoneFromAsset('assets/timezones/argentina.json');

final DateTime bogotaLocal = VendemeTime.instance.convertUtcToLocal(
	nowUtc,
	zoneId: 'America/Bogota',
);
```

## JSON Format Reference
Timezone assets follow this structure:

```json
{
	"id": "America/Santiago",
	"fallbackMinutes": -180,
	"periods": [
		{
			"start": "2024-04-07T04:00:00Z",
			"end": "2024-09-08T03:00:00Z",
			"offsetMinutes": -240
		}
	]
}
```

- `id`: unique identifier for the zone.
- `fallbackMinutes`: optional offset (minutes) used when an instant does not match any period.
- `periods`: ordered list of spans that define offsets. `start` and `end` must be ISO-8601 UTC strings (`end` can be omitted for the last open span).

## Testing
The repo contains widget tests under `test/` that exercise both in-memory registration and asset loading. Run them with:

```bash
flutter test
```

## Extending
- Add more JSON files under `assets/timezones/` and register them during bootstrap.
- Call `VendemeTime.instance.reset()` in tests or hot reload flows to clear custom registrations.
- Contributions are welcome: open an issue describing the timezone updates you need or send a PR with new assets and tests.

// Regenerates bundled time zone assets from the rules encoded in
// `lib/vendeme_time.dart`. Run from the package root:
//
//   dart run tool/generate_timezones.dart
//
// Extend the `--from` / `--to` flags (or edit the defaults below) to widen the
// window of pre-computed transitions.

import 'dart:convert';
import 'dart:io';

import 'package:vendeme_time/src/chile_rule.dart';

void main(List<String> args) {
  int fromYear = 2024;
  int toYear = 2040;
  for (int i = 0; i < args.length; i++) {
    final String a = args[i];
    if (a == '--from' && i + 1 < args.length) fromYear = int.parse(args[++i]);
    if (a == '--to' && i + 1 < args.length) toYear = int.parse(args[++i]);
  }

  final Map<String, Map<String, dynamic>> zones = <String, Map<String, dynamic>>{
    'assets/timezones/chile.json': buildChileTimeZone(
      fromYear: fromYear,
      toYear: toYear,
    ),
  };

  const JsonEncoder encoder = JsonEncoder.withIndent('    ');
  zones.forEach((String path, Map<String, dynamic> data) {
    final File f = File(path);
    f.parent.createSync(recursive: true);
    f.writeAsStringSync('${encoder.convert(data)}\n');
    stdout.writeln('wrote $path (${(data['periods'] as List).length} periods, $fromYear-$toYear)');
  });
}

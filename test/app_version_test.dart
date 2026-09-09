// The app has to know which version it is.
//
// `AppConfig.appVersion` was a hand-written constant. It drifted six releases behind
// pubspec, so every build reported 1.8.0 — and the moment a minimum version above that
// was published, every build blocked itself with "update the app" and offered no
// version to update to. The release script now passes the real value; this pins the
// fallback so the two can never disagree again.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/config.dart';

void main() {
  test('the fallback version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec has no version to compare against');
    expect(AppConfig.appVersion, match!.group(1),
        reason: 'bump AppConfig.appVersion with pubspec, or the build reports the wrong version');
  });

  test('the release script passes the real version', () {
    // Without this the shipped build falls back to whatever the constant says.
    final script = File('tool/testflight.sh').readAsStringSync();
    expect(script, contains('APP_VERSION=\$BUILD_NAME'));
  });
}

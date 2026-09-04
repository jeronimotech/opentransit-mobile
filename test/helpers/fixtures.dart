import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Reads a fixture straight from disk (tests run with the repo as cwd).
Map<String, dynamic> loadFixture(String name) => Map<String, dynamic>.from(
    jsonDecode(File('assets/fixtures/$name.json').readAsStringSync()) as Map);

/// [AssetBundle] backed by the local `assets/` folder so [MockApiClient] can
/// be exercised without a Flutter engine.
class DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsString();
}

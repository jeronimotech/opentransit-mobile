import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app icon on the home screen, in the rider's own city's colours.
///
/// Pure decoration, and deliberately opt-in: it is never changed because a city was selected, only
/// because someone asked for it. Changing it on Android kills the process and on iOS puts a system
/// alert on screen, neither of which is a thing to do to someone who was just looking at a bus.
class CityIcon {
  CityIcon({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('org.opentransit/city_icon');

  final MethodChannel _channel;

  /// Whether this platform can do it at all. A desktop or web build simply has no home screen.
  ///
  /// `defaultTargetPlatform` rather than `dart:io`'s `Platform`, because it is the one a test can
  /// override — and because it answers correctly on web instead of throwing.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// The city whose icon is showing, or null for the default one.
  Future<String?> current() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>('current');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Show [city]'s icon, or the default one when null.
  ///
  /// Returns false when the platform refused — an older device without alternate icon support, for
  /// instance. The caller shows that as "could not change it", never as a silent no-op: a rider who
  /// taps an icon and sees nothing happen will tap it again.
  Future<bool> select(String? city) async {
    if (!supported) return false;
    try {
      await _channel.invokeMethod<void>('select', {'city': city});
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

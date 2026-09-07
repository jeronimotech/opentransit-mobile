import 'common.dart';

/// State of a shared trip, mirrored on the public web page.
enum ShareState {
  onTime,
  delayed,
  arrived,
  cancelled;

  String get wire => switch (this) {
        ShareState.onTime => 'on_time',
        ShareState.delayed => 'delayed',
        ShareState.arrived => 'arrived',
        ShareState.cancelled => 'cancelled',
      };

  static ShareState parse(Object? v) => switch (v?.toString()) {
        'delayed' => delayed,
        'arrived' => arrived,
        'cancelled' => cancelled,
        _ => onTime,
      };
}

/// Progress pushed with `PATCH /share/eta/{token}`. Coordinates are coarsened
/// to 3 decimals (~110 m) *before* leaving the device, per the privacy rules.
class ShareProgress {
  const ShareProgress({
    required this.legIndex,
    this.atStopId,
    this.lat,
    this.lon,
    this.etaAt,
    this.state = ShareState.onTime,
  });
  final int legIndex;
  final String? atStopId;
  final double? lat;
  final double? lon;
  final DateTime? etaAt;
  final ShareState state;

  static double _coarse(double v) => (v * 1000).roundToDouble() / 1000;

  ShareProgress.at({
    required this.legIndex,
    required double latitude,
    required double longitude,
    this.atStopId,
    this.etaAt,
    this.state = ShareState.onTime,
  })  : lat = _coarse(latitude),
        lon = _coarse(longitude);

  Map<String, dynamic> toJson() => {
        'legIndex': legIndex,
        if (atStopId != null) 'atStopId': atStopId,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (etaAt != null) 'etaAt': etaAt!.toIso8601String(),
        'state': state.wire,
      };

  factory ShareProgress.fromJson(Map<String, dynamic> j) => ShareProgress(
        legIndex: asInt(j['legIndex']) ?? 0,
        atStopId: j['atStopId']?.toString(),
        lat: asDouble(j['lat']),
        lon: asDouble(j['lon']),
        etaAt: parseTime(j['etaAt']),
        state: ShareState.parse(j['state']),
      );
}

/// What `POST /share/eta` returns. [writeKey] is shown once and never leaves
/// the device; it authorises PATCH and DELETE.
class SharedTrip {
  const SharedTrip({
    required this.token,
    required this.url,
    required this.writeKey,
    this.expiresAt,
  });
  final String token;
  final String url;
  final String writeKey;
  final DateTime? expiresAt;

  factory SharedTrip.fromJson(Map<String, dynamic> j) => SharedTrip(
        token: j['token']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
        writeKey: (j['writeKey'] ?? j['write_key'])?.toString() ?? '',
        expiresAt: parseTime(j['expiresAt']),
      );
}

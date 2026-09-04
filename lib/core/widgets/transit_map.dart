import 'dart:math' show Point;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../config.dart';
import '../models/common.dart';
import '../utils/geo.dart';

/// A polyline drawn on the map.
class MapLine {
  const MapLine({
    required this.id,
    required this.points,
    required this.color,
    this.width = 5,
    this.dashed = false,
  });
  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;
  final bool dashed;
}

/// A point feature (stop, vehicle, marker).
class MapPoint {
  const MapPoint({
    required this.id,
    required this.position,
    required this.color,
    this.radius = 6,
    this.strokeColor = Colors.white,
    this.strokeWidth = 1.5,
    this.label,
    this.bearing,
    this.opacity = 1,
  });
  final String id;
  final LatLng position;
  final Color color;
  final double radius;
  final Color strokeColor;
  final double strokeWidth;
  final String? label;

  /// Heading in degrees (0 = north); drawn as a tick on vehicle markers.
  final double? bearing;
  final double opacity;
}

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

Map<String, dynamic> _emptyFc() =>
    {'type': 'FeatureCollection', 'features': const <Map<String, dynamic>>[]};

Map<String, dynamic> _lineFc(List<MapLine> lines) => {
      'type': 'FeatureCollection',
      'features': [
        for (final l in lines)
          if (l.points.length >= 2)
            {
              'type': 'Feature',
              'id': l.id,
              'properties': {
                'id': l.id,
                'color': _hex(l.color),
                'width': l.width,
                'dashed': l.dashed,
              },
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  for (final p in l.points) [p.lon, p.lat],
                ],
              },
            },
      ],
    };

Map<String, dynamic> _pointFc(List<MapPoint> pts) => {
      'type': 'FeatureCollection',
      'features': [
        for (final p in pts)
          {
            'type': 'Feature',
            'id': p.id,
            'properties': {
              'id': p.id,
              'color': _hex(p.color),
              'radius': p.radius,
              'stroke': _hex(p.strokeColor),
              'strokeWidth': p.strokeWidth,
              'label': p.label ?? '',
              'opacity': p.opacity,
              'bearing': p.bearing ?? -1,
              'hasBearing': p.bearing != null,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [p.position.lon, p.position.lat],
            },
          },
      ],
    };

/// MapLibre map with three GeoJSON overlays (lines, stops, vehicles) plus
/// origin/destination markers. All overlays are passed declaratively; the
/// widget diffs by identity and pushes changes to the native map.
class TransitMap extends StatefulWidget {
  const TransitMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 12,
    this.lines = const [],
    this.stops = const [],
    this.vehicles = const [],
    this.markers = const [],
    this.pois = const [],
    this.fitTo,
    this.fitPadding = const EdgeInsets.fromLTRB(40, 120, 40, 260),
    this.myLocation = false,
    this.onLongPress,
    this.onStopTap,
    this.onVehicleTap,
    this.onPoiTap,
    this.onCameraIdle,
    this.onMapReady,
    this.attributionBottomInset = 0,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final List<MapLine> lines;
  final List<MapPoint> stops;
  final List<MapPoint> vehicles;
  final List<MapPoint> markers;

  /// Points of interest (station services); `label` is drawn inside.
  final List<MapPoint> pois;

  /// When this list changes (by identity) the camera fits to it.
  final List<LatLng>? fitTo;
  final EdgeInsets fitPadding;
  final bool myLocation;
  final void Function(LatLng)? onLongPress;
  final void Function(String id)? onStopTap;
  final void Function(String id)? onVehicleTap;
  final void Function(String id)? onPoiTap;
  final void Function(LatLng center, double zoom)? onCameraIdle;
  final VoidCallback? onMapReady;
  final double attributionBottomInset;

  @override
  State<TransitMap> createState() => TransitMapState();
}

class TransitMapState extends State<TransitMap> {
  ml.MapLibreMapController? _c;
  bool _ready = false;

  static const _srcLines = 'ot-lines';
  static const _srcStops = 'ot-stops';
  static const _srcVehicles = 'ot-vehicles';
  static const _srcMarkers = 'ot-markers';
  static const _srcPois = 'ot-pois';

  /// Current visible bounds `[minLon, minLat, maxLon, maxLat]`, if known.
  Future<List<double>?> visibleBounds() async {
    final c = _c;
    if (c == null) return null;
    try {
      final b = await c.getVisibleRegion();
      return [b.southwest.longitude, b.southwest.latitude, b.northeast.longitude, b.northeast.latitude];
    } on PlatformException {
      return null;
    }
  }

  Future<void> animateTo(LatLng p, {double? zoom}) async {
    final c = _c;
    if (c == null) return;
    final target = ml.LatLng(p.lat, p.lon);
    try {
      await c.animateCamera(zoom == null
          ? ml.CameraUpdate.newLatLng(target)
          : ml.CameraUpdate.newLatLngZoom(target, zoom));
    } on PlatformException {
      // map disposed mid-animation
    }
  }

  Future<void> fitBounds(List<LatLng> pts, {EdgeInsets? padding}) async {
    final c = _c;
    final b = boundsOf(pts);
    if (c == null || b == null) return;
    final pad = padding ?? widget.fitPadding;
    if (pts.length == 1 || (b[0] == b[2] && b[1] == b[3])) {
      await animateTo(pts.first, zoom: 15);
      return;
    }
    if (!mounted) return;
    try {
      await c.animateCamera(
        ml.CameraUpdate.newLatLngBounds(
          ml.LatLngBounds(
            southwest: ml.LatLng(b[1], b[0]),
            northeast: ml.LatLng(b[3], b[2]),
          ),
          left: pad.left,
          top: pad.top,
          right: pad.right,
          bottom: pad.bottom,
        ),
      );
    } on PlatformException {
      // map disposed mid-animation
    }
  }

  Future<void> _onStyleLoaded() async {
    final c = _c;
    if (c == null || !mounted) return;
    try {
      await _addLayers(c);
    } on PlatformException {
      return; // map disposed mid-setup
    }
    c.onFeatureTapped.add(_onFeatureTapped);
    _ready = true;
    await _syncAll();
    if (widget.fitTo != null && widget.fitTo!.isNotEmpty) {
      await fitBounds(widget.fitTo!);
    }
    widget.onMapReady?.call();
  }

  Future<void> _addLayers(ml.MapLibreMapController c) async {
    await c.addGeoJsonSource(_srcLines, _emptyFc(), promoteId: 'id');
    await c.addLineLayer(
      _srcLines,
      'ot-lines-casing',
      const ml.LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: ['+', ['get', 'width'], 3],
        lineOpacity: 0.9,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: ['!', ['get', 'dashed']],
    );
    await c.addLineLayer(
      _srcLines,
      'ot-lines-layer',
      const ml.LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: ['get', 'width'],
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: ['!', ['get', 'dashed']],
    );
    await c.addLineLayer(
      _srcLines,
      'ot-lines-dashed',
      const ml.LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: ['get', 'width'],
        lineDasharray: [0.2, 2],
        lineCap: 'round',
      ),
      filter: ['get', 'dashed'],
    );

    await c.addGeoJsonSource(_srcStops, _emptyFc(), promoteId: 'id');
    await c.addCircleLayer(
      _srcStops,
      'ot-stops-layer',
      const ml.CircleLayerProperties(
        circleColor: ['get', 'color'],
        circleRadius: ['get', 'radius'],
        circleStrokeColor: ['get', 'stroke'],
        circleStrokeWidth: ['get', 'strokeWidth'],
      ),
    );
    await c.addSymbolLayer(
      _srcStops,
      'ot-stops-labels',
      const ml.SymbolLayerProperties(
        textField: ['get', 'label'],
        textSize: 11,
        textOffset: [0, 1.3],
        textAnchor: 'top',
        textFont: ['Noto Sans Regular'],
        textColor: '#1f2937',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.2,
        textOptional: true,
      ),
      minzoom: 14.5,
      enableInteraction: false,
    );

    await c.addGeoJsonSource(_srcVehicles, _emptyFc(), promoteId: 'id');
    await c.addCircleLayer(
      _srcVehicles,
      'ot-vehicles-layer',
      const ml.CircleLayerProperties(
        circleColor: ['get', 'color'],
        circleRadius: ['get', 'radius'],
        circleStrokeColor: ['get', 'stroke'],
        circleStrokeWidth: ['get', 'strokeWidth'],
        circleOpacity: ['get', 'opacity'],
        circleStrokeOpacity: ['get', 'opacity'],
      ),
    );
    // Bearing tick: a small white chevron rotated with the map, only for
    // vehicles that report a heading (UX audit §B, street zoom).
    await _addBearingIcon(c);
    await c.addSymbolLayer(
      _srcVehicles,
      'ot-vehicles-bearing',
      const ml.SymbolLayerProperties(
        iconImage: _bearingIcon,
        iconRotate: ['get', 'bearing'],
        iconRotationAlignment: 'map',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconSize: 0.5,
        iconOpacity: ['get', 'opacity'],
      ),
      filter: ['==', ['get', 'hasBearing'], true],
      minzoom: 15.5,
      enableInteraction: false,
    );
    // Route label sits under the dot (dark text, white halo) instead of
    // inside it, so it stays legible at street zoom.
    await c.addSymbolLayer(
      _srcVehicles,
      'ot-vehicles-labels',
      const ml.SymbolLayerProperties(
        textField: ['get', 'label'],
        textSize: 10,
        textFont: ['Noto Sans Bold'],
        textColor: '#1f2937',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.2,
        textOffset: [0, 0.9],
        textAnchor: 'top',
        textAllowOverlap: false,
        textOptional: true,
      ),
      minzoom: 16,
      enableInteraction: false,
    );

    await c.addGeoJsonSource(_srcPois, _emptyFc(), promoteId: 'id');
    await c.addCircleLayer(
      _srcPois,
      'ot-pois-layer',
      const ml.CircleLayerProperties(
        circleColor: ['get', 'color'],
        circleRadius: ['get', 'radius'],
        circleStrokeColor: ['get', 'stroke'],
        circleStrokeWidth: ['get', 'strokeWidth'],
        circleOpacity: 0.95,
      ),
      minzoom: 12,
    );
    await c.addSymbolLayer(
      _srcPois,
      'ot-pois-glyphs',
      const ml.SymbolLayerProperties(
        textField: ['get', 'label'],
        textSize: 9,
        textFont: ['Noto Sans Bold'],
        textColor: '#ffffff',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      minzoom: 13,
      enableInteraction: false,
    );

    await c.addGeoJsonSource(_srcMarkers, _emptyFc(), promoteId: 'id');
    await c.addCircleLayer(
      _srcMarkers,
      'ot-markers-layer',
      const ml.CircleLayerProperties(
        circleColor: ['get', 'color'],
        circleRadius: ['get', 'radius'],
        circleStrokeColor: ['get', 'stroke'],
        circleStrokeWidth: ['get', 'strokeWidth'],
      ),
      enableInteraction: false,
    );
  }

  static const _bearingIcon = 'ot-bearing';

  /// Draws a 24×24 white chevron pointing up and registers it as a style image.
  Future<void> _addBearingIcon(ml.MapLibreMapController c) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Chevron sitting just above the circle centre so it reads as a heading.
    final path = Path()
      ..moveTo(6, 8)
      ..lineTo(12, 2)
      ..lineTo(18, 8);
    canvas.drawPath(path, paint..color = Colors.black.withValues(alpha: 0.35)..strokeWidth = 5.5);
    canvas.drawPath(path, paint..color = Colors.white..strokeWidth = 3.5);
    final img = await rec.endRecording().toImage(24, 24);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    try {
      await c.addImage(_bearingIcon, bytes.buffer.asUint8List());
    } on PlatformException {
      // style gone
    }
  }

  void _onFeatureTapped(Point<double> point, ml.LatLng coords, String id,
      String layerId, ml.Annotation? annotation) {
    if (layerId == 'ot-stops-layer') widget.onStopTap?.call(id);
    if (layerId == 'ot-vehicles-layer') widget.onVehicleTap?.call(id);
    if (layerId == 'ot-pois-layer') widget.onPoiTap?.call(id);
  }

  /// Pushes a source update, swallowing the `styleNotFound` PlatformException
  /// the native side raises when the map was disposed or its style reloaded
  /// while the call was in flight.
  Future<void> _setSource(String id, Map<String, dynamic> fc) async {
    final c = _c;
    if (c == null || !_ready || !mounted) return;
    try {
      await c.setGeoJsonSource(id, fc);
    } on PlatformException {
      // ignore: map gone or style not ready
    }
  }

  Future<void> _syncAll() async {
    await _setSource(_srcLines, _lineFc(widget.lines));
    await _setSource(_srcStops, _pointFc(widget.stops));
    await _setSource(_srcVehicles, _pointFc(widget.vehicles));
    await _setSource(_srcMarkers, _pointFc(widget.markers));
    await _setSource(_srcPois, _pointFc(widget.pois));
  }

  @override
  void didUpdateWidget(TransitMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final c = _c;
    if (c == null || !_ready) return;
    if (!identical(oldWidget.lines, widget.lines)) {
      _setSource(_srcLines, _lineFc(widget.lines));
    }
    if (!identical(oldWidget.stops, widget.stops)) {
      _setSource(_srcStops, _pointFc(widget.stops));
    }
    if (!identical(oldWidget.vehicles, widget.vehicles)) {
      _setSource(_srcVehicles, _pointFc(widget.vehicles));
    }
    if (!identical(oldWidget.markers, widget.markers)) {
      _setSource(_srcMarkers, _pointFc(widget.markers));
    }
    if (!identical(oldWidget.pois, widget.pois)) {
      _setSource(_srcPois, _pointFc(widget.pois));
    }
    if (!identical(oldWidget.fitTo, widget.fitTo) &&
        widget.fitTo != null &&
        widget.fitTo!.isNotEmpty) {
      fitBounds(widget.fitTo!);
    }
  }

  @override
  void dispose() {
    _c?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ml.MapLibreMap(
      styleString: dark ? AppConfig.mapStyleDark : AppConfig.mapStyle,
      initialCameraPosition: ml.CameraPosition(
        target: ml.LatLng(widget.initialCenter.lat, widget.initialCenter.lon),
        zoom: widget.initialZoom,
      ),
      onMapCreated: (c) => _c = c,
      // No managed annotations: every overlay is a GeoJSON source + layer.
      // This also avoids the plugin's own source setup racing a dispose.
      annotationOrder: const [],
      onStyleLoadedCallback: _onStyleLoaded,
      trackCameraPosition: true,
      compassEnabled: false,
      myLocationEnabled: widget.myLocation,
      attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
      attributionButtonMargins:
          Point<num>(8, 8 + widget.attributionBottomInset),
      logoViewMargins: Point<num>(8, 8 + widget.attributionBottomInset),
      onMapLongClick: widget.onLongPress == null
          ? null
          : (_, ll) => widget.onLongPress!(LatLng(ll.latitude, ll.longitude)),
      onCameraIdle: widget.onCameraIdle == null
          ? null
          : () {
              final p = _c?.cameraPosition;
              if (p != null) {
                widget.onCameraIdle!(
                    LatLng(p.target.latitude, p.target.longitude), p.zoom);
              }
            },
    );
  }
}

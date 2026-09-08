import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_actions.dart';
import 'planner_state.dart';
import 'widgets/place_result_tile.dart';

/// Geocode autocomplete for the origin (`field=from`) or destination (`to`).
///
/// Contract v2.1: results are not destinations-only. Tapping a row fills the
/// field the screen was opened for; the row's overflow always offers both
/// "usar como origen" and "usar como destino", and the list is headed by
/// "mi ubicación" and "elegir en el mapa" for whichever field is being filled.
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({
    super.key,
    required this.cityId,
    required this.field,
    this.saveAs,
    this.implicit = false,
  });
  final String cityId;
  final String field;

  /// True when the caller did not name a field (a bare `/city/search` deep
  /// link). The screen then fills whichever end is still empty instead of
  /// overwriting the one that is set.
  final bool implicit;

  /// When set (`home` | `work`), the picked place is saved as that favorite
  /// instead of being put into the planner.
  final String? saveAs;

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GeocodeResult> _results = const [];
  bool _loading = false;
  Object? _error;
  int _seq = 0;
  LatLng? _here;

  /// The end of the trip this screen fills. With an explicit field that is the
  /// field itself — the user asked to edit it. Opened without one, the empty
  /// end wins so a filled field is never silently overwritten.
  PlaceField get _field {
    final preferred = PlaceField.parse(widget.field);
    return widget.implicit
        ? implicitTarget(ref.read(plannerProvider), preferred)
        : preferred;
  }

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final p = await currentPosition();
      if (mounted) setState(() => _here = p);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    if (q.trim().isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final city = await ref.read(cityProvider(widget.cityId).future);
      final r = await ref.read(apiClientProvider).geocode(widget.cityId, q, near: _here ?? city.center);
      if (seq != _seq || !mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (e) {
      if (seq != _seq || !mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _pickTracked(Place p,
      {required String resultType, int? position, String? id, PlaceField? field}) {
    final isStop = resultType == 'stop' || resultType == 'station';
    final target = field ?? _field;
    ref.read(analyticsProvider).track(Ev.searchSelect, {
      'resultType': resultType,
      'resultId': isStop ? (p.stopId ?? id) : null,
      'label': isStop || resultType == 'poi' ? p.name : null,
      'lat': p.position.lat,
      'lon': p.position.lon,
      'field': widget.saveAs != null ? 'favorite' : target.wire,
      'position': position,
    });
    _pick(p, field: target);
  }

  /// Writes [p] into [field] (the screen's own field unless the user picked the
  /// other end from the row overflow) and leaves. When the pick completes a
  /// pair that could not be planned before, the plan runs straight away.
  Future<void> _pick(Place p, {PlaceField? field}) async {
    if (widget.saveAs != null) {
      final kind = FavoriteKind.parse(widget.saveAs);
      final l10n = AppLocalizations.of(context);
      ref.read(favoritesProvider.notifier).put(Favorite.place(widget.cityId, p,
          kind: kind, icon: kind.name, name: kind == FavoriteKind.home ? l10n.favHome : l10n.favWork));
      context.pop();
      return;
    }
    final router = GoRouter.of(context);
    final canPlan = assignPlace(ref, field ?? _field, p);
    router.pop();
    if (canPlan) await runPlan(ref, router, widget.cityId);
  }

  /// Opens the full-screen map picker for [field]; it writes the place itself.
  void _chooseOnMap(PlaceField field) {
    final at = placeOf(ref.read(plannerProvider), field)?.position ?? _here;
    context.push(pickOnMapLocation(widget.cityId, field, at: at));
  }

  Future<void> _useMyLocation({PlaceField? field}) async {
    try {
      final p = await currentPosition();
      if (!mounted) return;
      await _pick(Place(name: AppLocalizations.of(context).myLocation, position: p),
          field: field);
    } on LocationDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).locationDenied)));
      }
    } catch (_) {
      // ignore transient location failures
    }
  }

  /// The row's secondary action: it fills the end the row is *not* for.
  ///
  /// Named rather than iconic. A tooltip only appears on a long press, so an
  /// unlabelled ring told nobody that the other end was reachable here.
  Widget _otherFieldButton(AppLocalizations l10n, Key key, VoidCallback onPressed) {
    final other = _field.other;
    return TextButton.icon(
      key: key,
      onPressed: onPressed,
      icon: Icon(
        other == PlaceField.from ? Icons.trip_origin : Icons.flag_outlined,
        size: 18,
      ),
      label: Text(other.label(l10n)),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final favs = ref.watch(favoritesProvider).where((f) => f.cityId == widget.cityId && f.type != FavoriteType.route).toList();
    final query = _controller.text.trim();
    // Nearby-first: with a fix, the closest stops lead the empty-query list.
    final nearby = _here == null ? null : ref.watch(nearbyStopsProvider(NearbyQuery(widget.cityId, _here!, radius: 800)));
    final near = nearby?.asData?.value ?? const <Stop>[];

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: _field.label(l10n),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
            isDense: true,
          ),
        ),
      ),
      body: ListView(
        children: [
          if (query.isEmpty) ...[
            // "Mi ubicación" and "Elegir en el mapa" are offered for whichever
            // field this screen is filling, origin included.
            ListTile(
              key: const ValueKey('search-my-location'),
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.my_location, color: scheme.onPrimaryContainer),
              ),
              title: Text(l10n.myLocation),
              subtitle: Text(_field.label(l10n)),
              onTap: _useMyLocation,
              // Labelled, not a bare ring: a tooltip only shows on long press, so
              // an icon alone leaves the second end undiscoverable. The result
              // rows name both ends in their menu; these two must match.
              trailing: widget.saveAs != null
                  ? null
                  : _otherFieldButton(
                      l10n,
                      const ValueKey('search-my-location-other'),
                      () => _useMyLocation(field: _field.other),
                    ),
            ),
            if (widget.saveAs == null)
              ListTile(
                key: const ValueKey('search-choose-on-map'),
                leading: CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(Icons.map_outlined, color: scheme.onSecondaryContainer),
                ),
                title: Text(l10n.chooseOnMap),
                subtitle: Text(_field.label(l10n)),
                onTap: () => _chooseOnMap(_field),
                trailing: _otherFieldButton(
                  l10n,
                  const ValueKey('search-choose-on-map-other'),
                  () => _chooseOnMap(_field.other),
                ),
              ),
            if (widget.saveAs == null && favs.isNotEmpty) SectionTitle(l10n.favorites),
            if (widget.saveAs == null)
              for (final f in favs)
                ListTile(
                  leading: Icon(f.type == FavoriteType.stop ? Icons.directions_bus : iconByName(f.icon, fallback: Icons.star), color: componentColor(f.component)),
                  title: Text(f.name),
                  subtitle: f.subtitle == null ? null : Text(f.subtitle!),
                  onTap: () => _pickTracked(f.toPlace(), resultType: f.type == FavoriteType.stop ? 'stop' : 'favorite'),
                ),
            if (near.isNotEmpty) SectionTitle(l10n.nearYou),
            for (final s in near.take(5))
              PlaceResultTile(
                tileKey: ValueKey('near-${s.id}'),
                name: s.name,
                type: s.isStation ? 'station' : 'stop',
                component: s.component,
                distanceMeters: s.distanceMeters,
                defaultField: _field,
                onPick: (field) => _pickTracked(
                    Place(name: s.name, position: s.position, stopId: s.id, component: s.component),
                    resultType: s.isStation ? 'station' : 'stop',
                    field: field),
              ),
          ],
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) ErrorView(error: _error!, onRetry: () => _search(query)),
          for (var i = 0; i < _results.length; i++)
            PlaceResultTile(
              tileKey: ValueKey('result-$i'),
              name: _results[i].name,
              type: _results[i].type,
              label: _results[i].label,
              component: _results[i].component,
              distanceMeters: _results[i].distanceMeters,
              defaultField: _field,
              onPick: (field) => _pickTracked(_results[i].toPlace(),
                  resultType: _results[i].type, position: i, field: field),
            ),
          if (!_loading && query.isNotEmpty && _results.isEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('—', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

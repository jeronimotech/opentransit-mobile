import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_state.dart';

/// Geocode autocomplete for the origin (`field=from`) or destination (`to`).
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key, required this.cityId, required this.field, this.saveAs});
  final String cityId;
  final String field;

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

  void _pick(Place p) {
    if (widget.saveAs != null) {
      final kind = FavoriteKind.parse(widget.saveAs);
      final l10n = AppLocalizations.of(context);
      ref.read(favoritesProvider.notifier).put(Favorite.place(widget.cityId, p,
          kind: kind, icon: kind.name, name: kind == FavoriteKind.home ? l10n.favHome : l10n.favWork));
      context.pop();
      return;
    }
    final planner = ref.read(plannerProvider.notifier);
    if (widget.field == 'from') {
      planner.setFrom(p);
    } else {
      planner.setTo(p);
    }
    context.pop();
  }

  Future<void> _useMyLocation() async {
    try {
      final p = await currentPosition();
      if (!mounted) return;
      _pick(Place(name: AppLocalizations.of(context).myLocation, position: p));
    } on LocationDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).locationDenied)));
      }
    } catch (_) {
      // ignore transient location failures
    }
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
            hintText: widget.field == 'from' ? l10n.fromLabel : l10n.toLabel,
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
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.my_location, color: scheme.onPrimaryContainer),
              ),
              title: Text(l10n.myLocation),
              onTap: _useMyLocation,
            ),
            if (widget.saveAs == null && favs.isNotEmpty) SectionTitle(l10n.favorites),
            if (widget.saveAs == null)
              for (final f in favs)
                ListTile(
                  leading: Icon(f.type == FavoriteType.stop ? Icons.directions_bus : iconByName(f.icon, fallback: Icons.star), color: componentColor(f.component)),
                  title: Text(f.name),
                  subtitle: f.subtitle == null ? null : Text(f.subtitle!),
                  onTap: () => _pick(f.toPlace()),
                ),
            if (near.isNotEmpty) SectionTitle(l10n.nearYou),
            for (final s in near.take(5))
              ListTile(
                leading: ComponentBadge(s.component, isStation: s.isStation),
                title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(s.distanceMeters == null ? '' : formatDistance(s.distanceMeters!)),
                onTap: () => _pick(Place(name: s.name, position: s.position, stopId: s.id, component: s.component)),
              ),
          ],
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) ErrorView(error: _error!, onRetry: () => _search(query)),
          for (final r in _results)
            ListTile(
              leading: _ResultIcon(r),
              title: Text(r.name),
              subtitle: r.label == null ? null : Text(r.label!, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _pick(r.toPlace()),
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

class _ResultIcon extends StatelessWidget {
  const _ResultIcon(this.r);
  final GeocodeResult r;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isStop = r.stopId != null;
    final bg = isStop ? componentColor(r.component) : scheme.surfaceContainerHighest;
    final icon = switch (r.type) {
      'station' => Icons.subway_outlined,
      'stop' => Icons.directions_bus,
      'address' => Icons.home_outlined,
      'street' => Icons.signpost_outlined,
      _ => Icons.place_outlined,
    };
    return CircleAvatar(
      backgroundColor: bg,
      child: Icon(icon, color: isStop ? onColor(bg) : scheme.onSurfaceVariant, size: 20),
    );
  }
}

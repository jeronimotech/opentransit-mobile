import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_state.dart';

/// Trip planning form (UX audit §C): one origin/destination block, one time
/// control, one non-wrapping mode row, "Más opciones" for the advanced
/// toggles, and the primary action pinned at the bottom. Accepts deep-link
/// query params (`fromLat, fromLon, toLat, toLon, fromName, toName, time, arriveBy`).
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key, required this.cityId, this.query = const {}});
  final String cityId;
  final Map<String, String> query;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyDeepLink());
  }

  void _applyDeepLink() {
    final q = widget.query;
    final planner = ref.read(plannerProvider.notifier);
    final fl = double.tryParse(q['fromLat'] ?? '');
    final fo = double.tryParse(q['fromLon'] ?? '');
    final tl = double.tryParse(q['toLat'] ?? '');
    final to = double.tryParse(q['toLon'] ?? '');
    var changed = false;
    if (fl != null && fo != null) {
      planner.setFrom(Place(name: q['fromName'] ?? '$fl,$fo', position: LatLng(fl, fo)));
      changed = true;
    }
    if (tl != null && to != null) {
      planner.setTo(Place(name: q['toName'] ?? '$tl,$to', position: LatLng(tl, to)));
      changed = true;
    }
    if (q['time'] != null) planner.setTime(DateTime.tryParse(q['time']!));
    if (q['arriveBy'] == 'true') planner.setArriveBy(true);
    if (changed && ref.read(plannerProvider).canPlan) _submit();
  }

  Future<void> _submit() async {
    final s = ref.read(plannerProvider);
    if (s.from != null && s.to != null) {
      // Remember the O/D pair for one-tap replanning (last 10, local only).
      await ref.read(recentTripsProvider.notifier).add(RecentTrip(
          cityId: widget.cityId, from: s.from!, to: s.to!, at: DateTime.now()));
    }
    final res = await ref.read(plannerProvider.notifier).plan(widget.cityId);
    if (!mounted) return;
    // Navigate even on error so the results screen shows the retry state.
    if (res != null || ref.read(plannerProvider).result != null) {
      context.push('/${widget.cityId}/results');
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final p = await currentPosition();
      if (!mounted) return;
      ref.read(plannerProvider.notifier).setFrom(
          Place(name: AppLocalizations.of(context).myLocation, position: p));
    } on LocationDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).locationDenied)));
      }
    } catch (_) {
      // ignore transient location failures
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Single time control: a sheet with *Salir a las / Llegar antes de* and
  /// "Ahora" or a date + time picker.
  Future<void> _openTimeSheet() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final s = ref.watch(plannerProvider);
        final locale = Localizations.localeOf(ctx).toString();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.timeSheetTitle, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l10n.departAt), icon: const Icon(Icons.logout, size: 16)),
                    ButtonSegment(value: true, label: Text(l10n.arriveBy), icon: const Icon(Icons.login, size: 16)),
                  ],
                  selected: {s.arriveBy},
                  onSelectionChanged: (v) => ref.read(plannerProvider.notifier).setArriveBy(v.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 8),
                RadioGroup<bool>(
                  groupValue: s.time == null,
                  onChanged: (v) async {
                    if (v == true) {
                      ref.read(plannerProvider.notifier).setTime(null);
                    } else {
                      await _pickTime(ctx);
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        value: true,
                        title: Text(l10n.timeNow),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<bool>(
                        value: false,
                        title: Text(s.time == null ? (s.arriveBy ? l10n.arriveBy : l10n.departAt) : formatDateShort(s.time!, locale)),
                        secondary: const Icon(Icons.schedule),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(l10n.done),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _pickTime(BuildContext ctx) async {
    final now = DateTime.now();
    final current = ref.read(plannerProvider).time ?? now;
    final date = await showDatePicker(
      context: ctx,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !ctx.mounted) return;
    final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return;
    ref.read(plannerProvider.notifier).setTime(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  /// Toggles a transit mode, expanding the `TRANSIT` shorthand when needed.
  void _toggleMode(TravelMode m, City city) {
    final planner = ref.read(plannerProvider.notifier);
    final s = ref.read(plannerProvider);
    final transitModes = city.modes.where((x) => x.isTransit && x != TravelMode.transit).toSet();
    final next = {...s.modes};
    if (next.remove(TravelMode.transit)) next.addAll(transitModes);
    if (!next.remove(m)) next.add(m);
    if (transitModes.isNotEmpty && next.containsAll(transitModes)) {
      next.removeAll(transitModes);
      next.add(TravelMode.transit);
    }
    planner.setModes(next);
  }

  bool _selected(TravelMode m, PlannerState s) =>
      s.modes.contains(m) || (m.isTransit && s.modes.contains(TravelMode.transit));

  String _shortModeLabel(TravelMode m, AppLocalizations l10n) => switch (m) {
        TravelMode.bicycle => l10n.modeBike,
        TravelMode.walk => l10n.modeWalkShort,
        _ => modeLabel(m, l10n),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(plannerProvider);
    final settings = ref.watch(settingsProvider);
    final city = ref.watch(cityProvider(widget.cityId)).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final loading = s.result?.isLoading ?? false;
    final favs = ref.watch(favoritesProvider.notifier);
    ref.watch(favoritesProvider);
    final home = favs.ofKind(widget.cityId, FavoriteKind.home);
    final work = favs.ofKind(widget.cityId, FavoriteKind.work);
    final recents = ref.watch(recentTripsProvider).where((t) => t.cityId == widget.cityId).take(5).toList();
    final bikeAllowed = (city?.modes.contains(TravelMode.bicycle) ?? false) && (city?.config.isEnabled('bike') ?? true);

    final timeLabel = s.time == null
        ? l10n.timeNow
        : '${s.arriveBy ? l10n.arriveBy : l10n.departAt} ${formatDateShort(s.time!, locale)}';

    final modes = <TravelMode>[
      if (city != null) ...city.modes.where((m) => m != TravelMode.walk && m != TravelMode.transit),
      TravelMode.walk,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planTrip)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Origin / destination
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Column(
                  children: [
                    Icon(Icons.trip_origin, size: 16, color: scheme.primary),
                    Container(width: 2, height: 28, color: scheme.outlineVariant),
                    Icon(Icons.location_on, size: 18, color: scheme.error),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _PlaceField(
                        label: l10n.fromLabel,
                        place: s.from,
                        trailing: IconButton(
                          tooltip: l10n.myLocation,
                          onPressed: _locating ? null : _useMyLocation,
                          icon: _locating
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 20),
                        ),
                        onTap: () => context.push('/${widget.cityId}/search?field=from'),
                      ),
                      const Divider(height: 8),
                      _PlaceField(
                        label: l10n.toLabel,
                        place: s.to,
                        onTap: () => context.push('/${widget.cityId}/search?field=to'),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.swap,
                  onPressed: () => ref.read(plannerProvider.notifier).swap(),
                  icon: const Icon(Icons.swap_vert),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Casa / Trabajo shortcuts
          if (home != null || work != null) ...[
            Wrap(
              spacing: 8,
              children: [
                if (home != null)
                  ActionChip(
                    key: const ValueKey('chip-home'),
                    avatar: const Icon(Icons.home_rounded, size: 16),
                    label: Text(l10n.favHome),
                    onPressed: () => ref.read(plannerProvider.notifier).setTo(home.toPlace()),
                  ),
                if (work != null)
                  ActionChip(
                    key: const ValueKey('chip-work'),
                    avatar: const Icon(Icons.work_rounded, size: 16),
                    label: Text(l10n.favWork),
                    onPressed: () => ref.read(plannerProvider.notifier).setTo(work.toPlace()),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // One time row: "[Ahora ▾]" opens the sheet (no duplicate chip).
          Row(
            children: [
              ActionChip(
                key: const ValueKey('time-control'),
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(timeLabel),
                onPressed: _openTimeSheet,
                backgroundColor: s.time != null ? scheme.secondaryContainer : null,
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),

          // One mode row that fits: Bus · Cable · Bici · A pie
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in modes) ...[
                  FilterChip(
                    key: ValueKey('mode-${m.name}'),
                    avatar: Icon(modeIcon(m), size: 16),
                    label: Text(_shortModeLabel(m, l10n)),
                    selected: m == TravelMode.walk ? s.modes.contains(TravelMode.walk) : _selected(m, s),
                    onSelected: (_) => m == TravelMode.walk
                        ? ref.read(plannerProvider.notifier).toggleMode(TravelMode.walk)
                        : (city == null ? null : _toggleMode(m, city)),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // "Más opciones" disclosure with the advanced toggles.
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const ValueKey('more-options'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(l10n.moreOptions, style: const TextStyle(fontWeight: FontWeight.w600)),
              initiallyExpanded: settings.bikeToStation || settings.wheelchair,
              children: [
                if (bikeAllowed)
                  SwitchListTile(
                    key: const ValueKey('bike-toggle'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.pedal_bike),
                    title: Text(l10n.bikeToStation),
                    value: settings.bikeToStation,
                    onChanged: (v) {
                      ref.read(settingsProvider.notifier).setBikeToStation(v);
                      final planner = ref.read(plannerProvider.notifier);
                      final modes = {...ref.read(plannerProvider).modes};
                      if (v) {
                        modes.add(TravelMode.bicycle);
                      } else {
                        modes.remove(TravelMode.bicycle);
                      }
                      planner.setModes(modes);
                    },
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.accessible),
                  title: Text(l10n.wheelchair),
                  value: settings.wheelchair,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setWheelchair(v),
                ),
              ],
            ),
          ),

          if (recents.isNotEmpty) ...[
            SectionTitle(l10n.recentTrips),
            for (final t in recents)
              ListTile(
                key: ValueKey('recent-${t.key}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history, color: scheme.onSurfaceVariant),
                title: Text('${t.from.name} → ${t.to.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  final planner = ref.read(plannerProvider.notifier);
                  planner.setFrom(t.from);
                  planner.setTo(t.to);
                  _submit();
                },
              ),
          ],
        ],
      ),
      // Primary CTA pinned at the bottom.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: s.canPlan && !loading ? _submit : null,
          icon: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(l10n.searchAction),
        ),
      ),
    );
  }
}

class _PlaceField extends StatelessWidget {
  const _PlaceField({required this.label, required this.place, required this.onTap, this.trailing});
  final String label;
  final Place? place;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(
                      place?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: place == null ? FontWeight.w400 : FontWeight.w600,
                            color: place == null ? scheme.onSurfaceVariant : scheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

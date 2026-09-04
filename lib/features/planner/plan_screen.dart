import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_state.dart';

/// Trip planning form. Accepts deep-link query params
/// (`fromLat, fromLon, toLat, toLon, fromName, toName, time, arriveBy`).
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

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final current = ref.read(plannerProvider).time ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return;
    ref.read(plannerProvider.notifier).setTime(
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  /// Toggles a transit mode, expanding the `TRANSIT` shorthand when needed.
  void _toggleMode(TravelMode m, City city) {
    final planner = ref.read(plannerProvider.notifier);
    final s = ref.read(plannerProvider);
    final transitModes = city.modes.where((x) => x.isTransit && x != TravelMode.transit).toSet();
    // Expand the TRANSIT shorthand into the city's concrete transit modes.
    final next = {...s.modes};
    if (next.remove(TravelMode.transit)) next.addAll(transitModes);
    if (!next.remove(m)) next.add(m);
    // Collapse back to TRANSIT when every transit mode is selected.
    if (transitModes.isNotEmpty && next.containsAll(transitModes)) {
      next.removeAll(transitModes);
      next.add(TravelMode.transit);
    }
    planner.setModes(next);
  }

  bool _selected(TravelMode m, PlannerState s) =>
      s.modes.contains(m) || (m.isTransit && s.modes.contains(TravelMode.transit));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(plannerProvider);
    final settings = ref.watch(settingsProvider);
    final city = ref.watch(cityProvider(widget.cityId)).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final loading = s.result?.isLoading ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planTrip)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
          const SizedBox(height: 16),

          // Time
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l10n.departAt), icon: const Icon(Icons.logout, size: 16)),
                    ButtonSegment(value: true, label: Text(l10n.arriveBy), icon: const Icon(Icons.login, size: 16)),
                  ],
                  selected: {s.arriveBy},
                  onSelectionChanged: (v) => ref.read(plannerProvider.notifier).setArriveBy(v.first),
                  showSelectedIcon: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.now),
                selected: s.time == null,
                onSelected: (_) => ref.read(plannerProvider.notifier).setTime(null),
              ),
              ActionChip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(s.time == null ? l10n.departAt : formatDateShort(s.time!, locale)),
                onPressed: _pickTime,
                backgroundColor: s.time != null ? scheme.secondaryContainer : null,
              ),
            ],
          ),

          // Modes
          SectionTitle(l10n.modes),
          if (city != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in city.modes.where((m) => m != TravelMode.walk && m != TravelMode.transit))
                  FilterChip(
                    avatar: Icon(modeIcon(m), size: 16),
                    label: Text(modeLabel(m, l10n)),
                    selected: _selected(m, s),
                    onSelected: (_) => _toggleMode(m, city),
                  ),
                FilterChip(
                  avatar: const Icon(Icons.directions_walk, size: 16),
                  label: Text(l10n.modeWalk),
                  selected: s.modes.contains(TravelMode.walk),
                  onSelected: (_) => ref.read(plannerProvider.notifier).toggleMode(TravelMode.walk),
                ),
              ],
            ),

          // Accessibility
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.accessible),
            title: Text(l10n.wheelchair),
            value: settings.wheelchair,
            onChanged: (v) => ref.read(settingsProvider.notifier).setWheelchair(v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: s.canPlan && !loading ? _submit : null,
            icon: loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            label: Text(l10n.searchAction),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }
}

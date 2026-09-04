import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';

/// "Buscar ruta": searchable list with component filter chips.
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  final _q = TextEditingController();
  Component? _component;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final routes = ref.watch(routesProvider(widget.cityId));
    final city = ref.watch(currentCityProvider);
    final q = _norm(_q.text.trim());
    final components = city?.components.map((c) => c.id).toList() ??
        const [Component.trunk, Component.feeder, Component.dual, Component.zonal, Component.cable];

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.routesSearchHint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(_q.clear)),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                ChoiceChip(label: Text(l10n.allRoutes), selected: _component == null, onSelected: (_) => setState(() => _component = null)),
                for (final c in components) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(componentLabel(c, l10n, city: city)),
                    selected: _component == c,
                    onSelected: (_) => setState(() => _component = _component == c ? null : c),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: routes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(routesProvider(widget.cityId))),
        data: (all) {
          final seen = <String>{};
          final list = [
            for (final r in all)
              if ((_component == null || r.component == _component) &&
                  (q.isEmpty || _norm(r.shortName).contains(q) || _norm(r.longName).contains(q)) &&
                  seen.add('${r.shortName}|${r.component?.name}'))
                r,
          ];
          if (list.isEmpty) return EmptyView(icon: Icons.route, message: l10n.noRoutes);
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return ListTile(
                leading: RouteChip(r),
                title: Text(r.longName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: r.serviceWindow == null
                    ? Text(componentLabel(r.component, l10n, city: city))
                    : (r.serviceWindow!.active
                        ? Text('${componentLabel(r.component, l10n, city: city)} · ${r.serviceWindow!.start} – ${r.serviceWindow!.end}')
                        : ServiceHint(r.serviceWindow, dense: true)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/${widget.cityId}/routes/${Uri.encodeComponent(r.id)}'),
              );
            },
          );
        },
      ),
    );
  }
}

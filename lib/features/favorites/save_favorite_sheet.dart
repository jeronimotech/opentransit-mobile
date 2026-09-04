import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../l10n/generated/app_localizations.dart';

/// Bottom sheet to save a place as Casa / Trabajo / custom (name + icon).
Future<void> showSaveFavoriteSheet(
    BuildContext context, WidgetRef ref, String cityId, Place place) async {
  final result = await showModalBottomSheet<Favorite>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _SaveFavoriteSheet(cityId: cityId, place: place),
  );
  if (result == null) return;
  await ref.read(favoritesProvider.notifier).put(result);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).addFavorite)));
  }
}

class _SaveFavoriteSheet extends StatefulWidget {
  const _SaveFavoriteSheet({required this.cityId, required this.place});
  final String cityId;
  final Place place;

  @override
  State<_SaveFavoriteSheet> createState() => _SaveFavoriteSheetState();
}

class _SaveFavoriteSheetState extends State<_SaveFavoriteSheet> {
  FavoriteKind _kind = FavoriteKind.custom;
  String _icon = 'star';
  late final _name = TextEditingController(text: widget.place.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.saveAs, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(widget.place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          SegmentedButton<FavoriteKind>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: FavoriteKind.home, icon: const Icon(Icons.home_rounded), label: Text(l10n.favHome)),
              ButtonSegment(value: FavoriteKind.work, icon: const Icon(Icons.work_rounded), label: Text(l10n.favWork)),
              ButtonSegment(value: FavoriteKind.custom, icon: const Icon(Icons.star_rounded), label: Text(l10n.favCustom)),
            ],
            selected: {_kind},
            onSelectionChanged: (v) => setState(() => _kind = v.first),
          ),
          if (_kind == FavoriteKind.custom) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.favoriteName),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Text(l10n.chooseIcon, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in customFavoriteIcons)
                  ChoiceChip(
                    key: ValueKey('icon-$name'),
                    label: Icon(iconByName(name), size: 20),
                    selected: _icon == name,
                    onSelected: (_) => setState(() => _icon = name),
                    showCheckmark: false,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              final fav = Favorite.place(
                widget.cityId,
                widget.place,
                kind: _kind,
                icon: _kind == FavoriteKind.custom ? _icon : _kind.name,
                name: switch (_kind) {
                  FavoriteKind.home => l10n.favHome,
                  FavoriteKind.work => l10n.favWork,
                  FavoriteKind.custom => _name.text.trim().isEmpty ? widget.place.name : _name.text.trim(),
                },
              );
              Navigator.pop(context, fav);
            },
            icon: const Icon(Icons.check),
            label: Text(l10n.saveFavorite),
          ),
        ],
      ),
    );
  }
}

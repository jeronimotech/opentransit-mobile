import 'package:flutter/material.dart';

import '../utils/colors.dart';

/// One entry of a [ModeGrid]: icon on top, short label (≤ 9 chars) below.
class ModeGridItem {
  const ModeGridItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onToggle,
    this.semanticsLabel,
  });

  /// Widget key suffix (`mode-<id>`), stable for tests and walkthroughs.
  final String id;
  final String label;
  final IconData icon;
  final bool selected;

  /// Fill colour when selected; outline / icon colour when not.
  final Color color;
  final ValueChanged<bool> onToggle;

  /// Spoken name (defaults to [label]).
  final String? semanticsLabel;
}

/// Non-scrolling grid of mode toggles: six fit in one row on 375–430 pt wide
/// screens (min 52 pt wide, 44 pt tall, 8 pt gaps); more than six wrap to a
/// second row. Selected = filled with the mode colour, unselected = outlined.
class ModeGrid extends StatelessWidget {
  const ModeGrid({
    super.key,
    required this.items,
    required this.onLabel,
    required this.offLabel,
    this.perRow = 6,
    this.gap = 8,
    this.minWidth = 52,
    this.height = 44,
  });
  final List<ModeGridItem> items;

  /// Localised state words for the semantics label ("Bus, activado").
  final String onLabel;
  final String offLabel;
  final int perRow;
  final double gap;
  final double minWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columns = items.length < perRow ? items.length : perRow;
      final raw = (c.maxWidth - gap * (columns - 1)) / columns;
      final width = raw.isFinite && raw >= minWidth ? raw : minWidth;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final it in items)
            SizedBox(
              width: width,
              height: height,
              child: ModeToggle(
                key: ValueKey('mode-${it.id}'),
                item: it,
                semanticsLabel: '${it.semanticsLabel ?? it.label}, ${it.selected ? onLabel : offLabel}',
              ),
            ),
        ],
      );
    });
  }
}

class ModeToggle extends StatelessWidget {
  const ModeToggle({super.key, required this.item, required this.semanticsLabel});
  final ModeGridItem item;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = ensureContrast(item.color, Colors.white);
    final fg = item.selected ? onColor(fill) : scheme.onSurface;
    return Semantics(
      button: true,
      selected: item.selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: item.selected ? fill : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: item.selected ? fill : scheme.outlineVariant, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => item.onToggle(!item.selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 18, color: item.selected ? fg : item.color),
                const SizedBox(height: 1),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg, height: 1.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

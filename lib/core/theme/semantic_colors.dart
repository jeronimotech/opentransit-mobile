import 'package:flutter/material.dart';

/// Colour semantics shared by every screen (Lote 1, Citymapper playbook):
/// live/positive is green, walking is blue, disruptions are orange, severe
/// problems are red. Widgets read these instead of `Colors.green.shade700`
/// so light and dark themes stay consistent and a city can retune them.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.live,
    required this.walk,
    required this.disruption,
    required this.severe,
    required this.info,
  });

  final Color live;
  final Color walk;
  final Color disruption;
  final Color severe;
  final Color info;

  static const light = SemanticColors(
    live: Color(0xFF2E7D32),
    walk: Color(0xFF1E6FB0),
    disruption: Color(0xFFE65100),
    severe: Color(0xFFC62828),
    info: Color(0xFF1565C0),
  );

  static const dark = SemanticColors(
    live: Color(0xFF66BB6A),
    walk: Color(0xFF64B5F6),
    disruption: Color(0xFFFFB74D),
    severe: Color(0xFFEF5350),
    info: Color(0xFF64B5F6),
  );

  static SemanticColors of(Brightness b) => b == Brightness.dark ? dark : light;

  @override
  SemanticColors copyWith({Color? live, Color? walk, Color? disruption, Color? severe, Color? info}) =>
      SemanticColors(
        live: live ?? this.live,
        walk: walk ?? this.walk,
        disruption: disruption ?? this.disruption,
        severe: severe ?? this.severe,
        info: info ?? this.info,
      );

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      live: Color.lerp(live, other.live, t)!,
      walk: Color.lerp(walk, other.walk, t)!,
      disruption: Color.lerp(disruption, other.disruption, t)!,
      severe: Color.lerp(severe, other.severe, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension SemanticColorsContext on BuildContext {
  /// The semantic palette of the current theme (falls back to light).
  SemanticColors get semantic =>
      Theme.of(this).extension<SemanticColors>() ?? SemanticColors.of(Theme.of(this).brightness);
}

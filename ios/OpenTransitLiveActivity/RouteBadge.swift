//  RouteBadge.swift
//  The coloured route chip, matching the app's own chip.

import SwiftUI

extension Color {
  /// Parses "#RRGGBB" (or "RRGGBB"). Falls back to the brand red rather than
  /// crashing on a malformed colour from the feed.
  init(hexOrBrand hex: String) {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else {
      self = Color(red: 0.72, green: 0.11, blue: 0.11)
      return
    }
    self = Color(
      red: Double((v >> 16) & 0xFF) / 255,
      green: Double((v >> 8) & 0xFF) / 255,
      blue: Double(v & 0xFF) / 255)
  }

  /// Readable ink for a filled badge: dark text on a light chip, white on a
  /// dark one, using the same relative-luminance rule as the app.
  var readableInk: Color {
    #if canImport(UIKit)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
    let lum = 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    return lum > 0.6 ? .black : .white
    #else
    return .white
    #endif
  }
}

struct RouteBadge: View {
  let shortName: String
  let colorHex: String
  var compact = false

  var body: some View {
    if shortName.isEmpty {
      Image(systemName: "figure.walk")
        .font(.system(size: compact ? 13 : 15, weight: .bold))
        .foregroundStyle(.secondary)
    } else {
      let bg = Color(hexOrBrand: colorHex)
      Text(shortName)
        .font(.system(size: compact ? 13 : 15, weight: .heavy, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(bg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .foregroundStyle(bg.readableInk)
    }
  }
}

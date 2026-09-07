//  OpenTransitLiveActivityBundle.swift
//  Widget bundle for the Live Activity extension.

import SwiftUI
import WidgetKit

@main
struct OpenTransitLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOS 16.2, *) {
      OpenTransitLiveActivity()
    }
  }
}

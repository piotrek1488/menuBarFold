import SwiftUI

struct SettingsRootView: View {
  @Bindable var model: AppModel
  @State private var selection: SettingsSection? = .overview

  var body: some View {
    NavigationSplitView {
      List(SettingsSection.allCases, selection: $selection) { section in
        Label(
          L10n.string("settings.section.\(section.rawValue)", language: model.language),
          systemImage: section.systemImage
        )
        .tag(section)
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 230)
      .listStyle(.sidebar)
    } detail: {
      detailView
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .navigationTitle("MenuBarFold")
    .frame(minWidth: 700, minHeight: 500)
  }

  @ViewBuilder
  private var detailView: some View {
    switch selection ?? .overview {
    case .overview:
      OverviewSettingsView(model: model)
    case .behavior:
      BehaviorSettingsView(model: model)
    case .shortcuts:
      ShortcutSettingsView(model: model)
    case .about:
      AboutView(model: model)
    }
  }
}

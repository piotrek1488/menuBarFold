import SwiftUI

struct BehaviorSettingsView: View {
  @Bindable var model: AppModel

  private let delays: [Double] = [3, 5, 10, 15, 30, 60]

  var body: some View {
    Form {
      Section(L10n.string("behavior.general", language: model.language)) {
        Toggle(
          L10n.string("behavior.launchAtLogin", language: model.language),
          isOn: $model.launchAtLoginEnabled
        )
        Toggle(
          L10n.string("behavior.showSettingsOnLaunch", language: model.language),
          isOn: $model.showSettingsOnLaunch
        )

        Picker(
          L10n.string("behavior.language", language: model.language),
          selection: $model.language
        ) {
          Text(L10n.string("language.system", language: model.language)).tag(AppLanguage.system)
          Text("English").tag(AppLanguage.english)
          Text("Polski").tag(AppLanguage.polish)
        }
      }

      Section(L10n.string("behavior.collapse", language: model.language)) {
        Toggle(
          L10n.string("behavior.autoCollapse", language: model.language),
          isOn: $model.autoCollapseEnabled
        )

        Picker(
          L10n.string("behavior.delay", language: model.language),
          selection: $model.autoCollapseDelay
        ) {
          ForEach(delays, id: \.self) { delay in
            Text(
              L10n.formatted(
                "behavior.seconds",
                language: model.language,
                arguments: Int(delay)
              )
            )
            .tag(delay)
          }
        }
        .disabled(!model.autoCollapseEnabled)

        Toggle(
          L10n.string("behavior.hoverReveal", language: model.language),
          isOn: $model.hoverToRevealEnabled
        )
      }

      Section {
        Toggle(
          L10n.string("behavior.alwaysHidden", language: model.language),
          isOn: $model.alwaysHiddenEnabled
        )

        Button(L10n.string("setup.arrange", language: model.language)) {
          model.beginArranging()
        }
        .disabled(!model.isAccessibilityGranted)
      } header: {
        Text(L10n.string("behavior.sections", language: model.language))
      } footer: {
        Text(L10n.string("behavior.alwaysHidden.help", language: model.language))
      }

      Section {
        Toggle(
          L10n.string("behavior.captureProtection", language: model.language),
          isOn: $model.protectCaptureIndicators
        )
      } header: {
        Text(L10n.string("behavior.privacy", language: model.language))
      } footer: {
        Text(L10n.string("behavior.captureProtection.help", language: model.language))
      }
    }
    .formStyle(.grouped)
    .padding(22)
  }
}

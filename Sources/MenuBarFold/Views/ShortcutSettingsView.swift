import SwiftUI

struct ShortcutSettingsView: View {
  @Bindable var model: AppModel

  var body: some View {
    Form {
      Section {
        Picker(
          L10n.string("shortcut.toggle", language: model.language),
          selection: $model.shortcutPreset
        ) {
          ForEach(ShortcutPreset.allCases) { preset in
            HStack {
              Text(shortcutName(preset))
              Spacer()
              Text(preset.displayValue)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
            }
            .tag(preset)
          }
        }
      } header: {
        Text(L10n.string("shortcut.title", language: model.language))
      } footer: {
        Text(L10n.string("shortcut.help", language: model.language))
      }

      Section(L10n.string("shortcut.menuBar", language: model.language)) {
        LabeledContent(L10n.string("shortcut.leftClick", language: model.language)) {
          Text(L10n.string("shortcut.leftClick.value", language: model.language))
            .foregroundStyle(.secondary)
        }
        LabeledContent(L10n.string("shortcut.rightClick", language: model.language)) {
          Text(L10n.string("shortcut.rightClick.value", language: model.language))
            .foregroundStyle(.secondary)
        }
        LabeledContent(L10n.string("shortcut.optionClick", language: model.language)) {
          Text(L10n.string("shortcut.optionClick.value", language: model.language))
            .foregroundStyle(.secondary)
        }
        LabeledContent(L10n.string("shortcut.commandDrag", language: model.language)) {
          Text(L10n.string("shortcut.commandDrag.value", language: model.language))
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .padding(22)
  }

  private func shortcutName(_ preset: ShortcutPreset) -> String {
    L10n.string("shortcut.preset.\(preset.rawValue)", language: model.language)
  }
}

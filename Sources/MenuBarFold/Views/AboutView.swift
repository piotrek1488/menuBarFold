import SwiftUI

struct AboutView: View {
  let model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 16) {
          ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(Color.accentColor.gradient)
            Image(systemName: "rectangle.topthird.inset.filled")
              .font(.system(size: 36, weight: .semibold))
              .foregroundStyle(.white)
          }
          .frame(width: 76, height: 76)

          VStack(alignment: .leading, spacing: 3) {
            Text("MenuBarFold")
              .font(.largeTitle.bold())
            Text(L10n.string("about.tagline", language: model.language))
              .foregroundStyle(.secondary)
            Text(
              L10n.formatted(
                "about.version",
                language: model.language,
                arguments: appVersion
              )
            )
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
        }

        SettingsCard {
          Text(L10n.string("about.privacy.title", language: model.language))
            .font(.headline)
          Text(L10n.string("about.privacy.detail", language: model.language))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        SettingsCard {
          Text(L10n.string("about.macos27.title", language: model.language))
            .font(.headline)
          Text(L10n.string("about.macos27.detail", language: model.language))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        SettingsCard {
          Text(L10n.string("about.acknowledgements.title", language: model.language))
            .font(.headline)
          Text(L10n.string("about.acknowledgements.detail", language: model.language))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(28)
      .frame(maxWidth: 680, alignment: .leading)
    }
  }

  private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "development"
  }
}

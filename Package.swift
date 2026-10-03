// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MenuBarFold",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "MenuBarFold", targets: ["MenuBarFold"])
  ],
  targets: [
    .target(
      name: "MenuBarPrivateBridge",
      path: "Sources/MenuBarPrivateBridge",
      publicHeadersPath: "include"
    ),
    .executableTarget(
      name: "MenuBarFold",
      dependencies: ["MenuBarPrivateBridge"],
      path: "Sources/MenuBarFold",
      resources: [
        .process("Resources")
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("ApplicationServices"),
        .linkedFramework("Carbon"),
        .linkedFramework("CoreAudio"),
        .linkedFramework("CoreMediaIO"),
        .linkedFramework("ServiceManagement"),
      ]
    ),
    .testTarget(
      name: "MenuBarFoldTests",
      dependencies: ["MenuBarFold"],
      path: "Tests/MenuBarFoldTests"
    ),
  ],
  swiftLanguageModes: [.v5]
)

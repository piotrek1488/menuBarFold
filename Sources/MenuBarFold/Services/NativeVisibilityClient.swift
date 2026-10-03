import Foundation
import MenuBarPrivateBridge

protocol NativeVisibilityAssertion: AnyObject {
  func invalidate()
}

protocol NativeVisibilityProviding: AnyObject {
  var isAvailable: Bool { get }

  func activate(
    allowedSystemItems: [Int],
    allowedBundleIdentifiers: [String],
    completion: @escaping (Result<NativeVisibilityAssertion, Error>) -> Void
  )
}

final class NativeVisibilityClient: NativeVisibilityProviding {
  var isAvailable: Bool {
    MBFNativeVisibilityIsAvailable()
  }

  func activate(
    allowedSystemItems: [Int],
    allowedBundleIdentifiers: [String],
    completion: @escaping (Result<NativeVisibilityAssertion, Error>) -> Void
  ) {
    MBFNativeVisibilityActivate(
      allowedSystemItems.map(NSNumber.init(value:)),
      allowedBundleIdentifiers
    ) { assertion, error in
      if let assertion {
        completion(.success(Handle(rawValue: assertion)))
      } else {
        completion(
          .failure(
            error
              ?? NSError(
                domain: "MenuBarFold.NativeVisibility",
                code: 2,
                userInfo: [
                  NSLocalizedDescriptionKey: "The visibility request returned no assertion."
                ]
              )
          )
        )
      }
    }
  }

  private final class Handle: NativeVisibilityAssertion {
    private var rawValue: Any?

    init(rawValue: Any) {
      self.rawValue = rawValue
    }

    func invalidate() {
      guard let rawValue else { return }
      self.rawValue = nil
      MBFNativeVisibilityInvalidate(rawValue)
    }

    deinit {
      invalidate()
    }
  }
}

// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

// swiftlint:disable sorted_imports
import Foundation
import UIKit

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Storyboard Scenes

// swiftlint:disable explicit_type_interface identifier_name line_length type_body_length type_name
internal enum StoryboardScene {
  internal enum KeyBackupRecoverFromPassphraseViewController: StoryboardType {
    internal static let storyboardName = "KeyBackupRecoverFromPassphraseViewController"

    internal static let initialScene = InitialSceneType<AMP_Chat.KeyBackupRecoverFromPassphraseViewController>(storyboard: KeyBackupRecoverFromPassphraseViewController.self)
  }
  internal enum KeyBackupRecoverFromRecoveryKeyViewController: StoryboardType {
    internal static let storyboardName = "KeyBackupRecoverFromRecoveryKeyViewController"

    internal static let initialScene = InitialSceneType<AMP_Chat.KeyBackupRecoverFromRecoveryKeyViewController>(storyboard: KeyBackupRecoverFromRecoveryKeyViewController.self)
  }
  internal enum KeyBackupRecoverSuccessViewController: StoryboardType {
    internal static let storyboardName = "KeyBackupRecoverSuccessViewController"

    internal static let initialScene = InitialSceneType<AMP_Chat.KeyBackupRecoverSuccessViewController>(storyboard: KeyBackupRecoverSuccessViewController.self)
  }
  internal enum KeyBackupSetupIntroViewController: StoryboardType {
    internal static let storyboardName = "KeyBackupSetupIntroViewController"

    internal static let initialScene = InitialSceneType<AMP_Chat.KeyBackupSetupIntroViewController>(storyboard: KeyBackupSetupIntroViewController.self)
  }
  internal enum KeyBackupSetupPassphraseViewController: StoryboardType {
    internal static let storyboardName = "KeyBackupSetupPassphraseViewController"

    internal static let initialScene = InitialSceneType<AMP_Chat.KeyBackupSetupPassphraseViewController>(storyboard: KeyBackupSetupPassphraseViewController.self)
  }
  internal enum KeyBackupSetupSuccessFromPassphraseViewController: StoryboardType {
    internal static let storyboardName = "KeyBackupSetupSuccessFromPassphraseViewController"

    internal static let initialScene = InitialSceneType<AMP_Chat.KeyBackupSetupSuccessFromPassphraseViewController>(storyboard: KeyBackupSetupSuccessFromPassphraseViewController.self)
  }
  internal enum KeyBackupSetupSuccessFromRecoveryKeyViewController: StoryboardType {
    internal static let storyboardName = "KeyBackupSetupSuccessFromRecoveryKeyViewController"

    internal static let initialScene = InitialSceneType<AMP_Chat.KeyBackupSetupSuccessFromRecoveryKeyViewController>(storyboard: KeyBackupSetupSuccessFromRecoveryKeyViewController.self)
  }
}
// swiftlint:enable explicit_type_interface identifier_name line_length type_body_length type_name

// MARK: - Implementation Details

internal protocol StoryboardType {
  static var storyboardName: String { get }
}

internal extension StoryboardType {
  static var storyboard: UIStoryboard {
    let name = self.storyboardName
    return UIStoryboard(name: name, bundle: Bundle(for: BundleToken.self))
  }
}

internal struct SceneType<T: UIViewController> {
  internal let storyboard: StoryboardType.Type
  internal let identifier: String

  internal func instantiate() -> T {
    let identifier = self.identifier
    guard let controller = storyboard.storyboard.instantiateViewController(withIdentifier: identifier) as? T else {
      fatalError("ViewController '\(identifier)' is not of the expected class \(T.self).")
    }
    return controller
  }
}

internal struct InitialSceneType<T: UIViewController> {
  internal let storyboard: StoryboardType.Type

  internal func instantiate() -> T {
    guard let controller = storyboard.storyboard.instantiateInitialViewController() as? T else {
      fatalError("ViewController is not of the expected class \(T.self).")
    }
    return controller
  }
}

private final class BundleToken {}

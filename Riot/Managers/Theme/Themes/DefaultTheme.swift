/*
 Copyright 2018 New Vector Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import UIKit

/// Color constants for the default theme
@objcMembers
class DefaultTheme: NSObject, Theme {

    var backgroundColor: UIColor = UIColor(rgb: 0xFFFFFF)

    var baseColor: UIColor = UIColor(rgb: 0xCC1E1C)
    var baseTextPrimaryColor: UIColor = UIColor(rgb: 0xFFFFFF)
    var baseTextSecondaryColor: UIColor = UIColor(rgb: 0xFFFFFF)

    var searchBackgroundColor: UIColor = UIColor(rgb: 0xCC1E1C)
    var searchPlaceholderColor: UIColor = UIColor(rgb: 0x8e8e8e)
    var searchCancelColor: UIColor = UIColor(rgb: 0xFFFFFF)

    var headerBackgroundColor: UIColor = UIColor(rgb: 0xCC1E1C)
    var headerBorderColor: UIColor  = UIColor(rgb: 0xE9EDF1)
    var headerTextPrimaryColor: UIColor = UIColor(rgb: 0xFFFFFF)
    var headerTextSecondaryColor: UIColor = UIColor.white.withAlphaComponent(0.7)

    var textPrimaryColor: UIColor = UIColor(rgb: 0x2E2F32)
    var textSecondaryColor: UIColor = UIColor(rgb: 0x9E9E9E)

    var tintColor: UIColor = UIColor(rgb: 0xFFFFFF)
    var textTintColor: UIColor = UIColor(rgb: 0xCC1E1C)
    var unreadRoomIndentColor: UIColor = UIColor(rgb: 0x2E3648)
    var lineBreakColor: UIColor = UIColor.black.withAlphaComponent(0.15)
    
    var noticeColor: UIColor = UIColor(rgb: 0xFF4B55)
    var noticeSecondaryColor: UIColor = UIColor(rgb: 0x61708B)

    var warningColor: UIColor = UIColor(rgb: 0xFF4B55)

    var avatarColors: [UIColor] = [
        UIColor(rgb: 0xe74c3c),
        UIColor(rgb: 0x34495e),
        UIColor(rgb: 0xe67e22)]
    
    var userNameColors: [UIColor] = [
        UIColor(rgb: 0x368BD6),
        UIColor(rgb: 0xAC3BA8),
        UIColor(rgb: 0x03B381),
        UIColor(rgb: 0xE64F7A),
        UIColor(rgb: 0xFF812D),
        UIColor(rgb: 0x2DC2C5),
        UIColor(rgb: 0x5C56F5),
        UIColor(rgb: 0x74D12C)
    ]

    var statusBarStyle: UIStatusBarStyle = .lightContent
    var scrollBarStyle: UIScrollView.IndicatorStyle = .default
    var keyboardAppearance: UIKeyboardAppearance = .light

    var placeholderTextColor: UIColor = UIColor(white: 0.7, alpha: 1.0) // Use default 70% gray color
    var selectedBackgroundColor: UIColor?  // Use the default selection color
    var overlayBackgroundColor: UIColor = UIColor(white: 0.7, alpha: 0.5)
    var matrixSearchBackgroundImageTintColor: UIColor = UIColor(rgb: 0xE7E7E7)
    
    func applyStyle(onTabBar tabBar: UITabBar) {
        tabBar.tintColor = self.tintColor
        tabBar.barTintColor = self.backgroundColor
        tabBar.isTranslucent = false
    }

    func applyStyle(onNavigationBar navigationBar: UINavigationBar) {
        navigationBar.tintColor = self.baseTextPrimaryColor
        navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: self.baseTextPrimaryColor
        ]
        navigationBar.barTintColor = self.baseColor
        navigationBar.barStyle = .black

        // The navigation bar needs to be opaque so that its background color is the expected one
        navigationBar.isTranslucent = false
    }

    func applyStyle(onSearchBar searchBar: UISearchBar) {
        searchBar.barStyle = .default
        searchBar.tintColor = self.searchPlaceholderColor
        searchBar.barTintColor = self.searchBackgroundColor
    }
    
    func applyStyle(onTextField texField: UITextField) {
        texField.textColor = self.textPrimaryColor
        texField.tintColor = self.tintColor
    }
    
    func applyStyle(onButton button: UIButton) {
        // NOTE: Tint color does nothing by default on button type `UIButtonType.custom`
        button.backgroundColor = self.baseColor
        button.tintColor = self.tintColor
        button.setTitleColor(self.headerTextPrimaryColor, for: .normal)
        button.setTitleColor(self.headerTextPrimaryColor.withAlphaComponent(0.4), for: .disabled)
    }
}

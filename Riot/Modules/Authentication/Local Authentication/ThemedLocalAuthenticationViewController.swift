//
//  ThemedLocalAuthenticationViewController.swift
//  Riot
//
//  Created by Marco Festini on 20.02.20.
//  Copyright © 2020 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class ThemedLocalAuthenticationViewController: LocalAuthenticationViewController {

    override func viewDidLoad() {
        let theme = ThemeService.shared().theme
        
        self.view.backgroundColor = theme.backgroundColor
        self.explanationLabel.textColor = theme.baseTextPrimaryColor
        
        theme.applyStyle(onButton: authenticateButton)
        
        super.viewDidLoad()
    }
}

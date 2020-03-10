//
//  ThemedLocalAuthenticationViewController.swift
//  Riot
//
//  Created by Marco Festini on 20.02.20.
//  Copyright © 2020 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class ThemedLocalAuthenticationViewController: LocalAuthenticationViewController {
    @IBOutlet weak private var topBar: UINavigationBar!
    @IBOutlet internal var topBarItem: UINavigationItem!

    override func viewDidLoad() {
        let theme = ThemeService.shared().theme
        
        self.view.backgroundColor = theme.backgroundColor
        self.explanationLabel.textColor = theme.baseTextPrimaryColor
        self.topBarItem.title = VectorL10n.localAuthenticationTitle
        
        theme.applyStyle(onButton: authenticateButton)
        theme.applyStyle(onNavigationBar: topBar)
        
        super.viewDidLoad()
    }
}

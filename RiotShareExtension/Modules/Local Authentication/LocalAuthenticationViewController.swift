//
//  LocalAuthenticationViewController.swift
//  Riot
//
//  Created by Marco Festini on 19.02.20.
//  Copyright © 2020 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit
import LocalAuthentication

class LocalAuthenticationViewController: UIViewController {
    private static var _isAuthenticated = false
    @objc static var isAuthenticated: Bool {
        get {
            let requireLocalAuthentication = UserDefaults.standard.bool(forKey: "requireLocalAuthentication")
            
            return LocalAuthenticationViewController._isAuthenticated || !requireLocalAuthentication
        }
    }
    @objc var successCallback: (() -> Void)?
    
    @IBOutlet internal weak var explanationLabel: UILabel!
    @IBOutlet internal weak var authenticateButton: UIButton!
    
    @objc var explanationInPrompt: String!
    @objc var explanation: String! {
        didSet {
            self.explanationLabel?.text = explanation
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.explanationLabel.text = explanation
        self.authenticateButton.setTitle(NSLocalizedString("local_authentication_retry", tableName: "Vector", comment: ""), for: .normal)
        self.authenticateButton.layer.cornerRadius = 5
        self.authenticateButton.isHidden = true
    }
    
    @objc static func invalidate() {
        print("[LocalAuthenticationViewController] invalidate: Invalidating previous authentication")
        _isAuthenticated = false
    }
    
    private func showAuthenticateButton() {
        DispatchQueue.main.async {
            self.authenticateButton.isHidden = false
        }
    }

    @IBAction private func authenticatePressed(_ sender: Any) {
        authenticate()
    }
    
    @objc func authenticate() {
        guard let callback = successCallback else { return }
        
        let context = LAContext()
        
        context.touchIDAuthenticationAllowableReuseDuration = 10
        
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: explanationInPrompt) { success, error in
                LocalAuthenticationViewController._isAuthenticated = success
                if success {
                    DispatchQueue.main.async {
                        callback()
                    }
                } else {
                    print(error?.localizedDescription ?? "[LocalAuthenticationViewController] authenticate: Failed to authenticate")
                    self.showAuthenticateButton()
                }
            }
        } else {
            print(error?.localizedDescription ?? "[LocalAuthenticationViewController] authenticate: Authentication policy not supported")
            
            guard let error = error else {
                return
            }
            
            switch error.code {
            case LAError.passcodeNotSet.rawValue:
                explanationLabel.text = NSLocalizedString("local_authentication_not_setup", tableName: "Vector", comment: "")
            case LAError.authenticationFailed.rawValue:
                print("[LocalAuthenticationViewController] authenticate: User has failed to authenticate")
                showAuthenticateButton()
                
            default:
                showAuthenticateButton()
            }
        }
    }
}

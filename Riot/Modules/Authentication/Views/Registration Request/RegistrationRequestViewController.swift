//
//  RegistrationRequestViewController.swift
//  Riot
//
//  Created by Marco Festini on 27.01.20.
//  Copyright © 2020 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class RegistrationRequestViewController: UIViewController {
    @IBOutlet weak var explanationLabel: UILabel!
    @IBOutlet weak var explanation2Label: UILabel!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var successLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var sendRequestButton: UIButton!
    @IBOutlet weak var activityView: UIView!
    
    let bugReport = MXBugReportRestClient(bugReportEndpoint: UserDefaults.standard.string(forKey: "bugReportEndpointUrl"))

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let theme = ThemeService.shared().theme
        
        activityView.isHidden = true
        
        explanationLabel.textColor = theme.textPrimaryColor
        explanationLabel.text = VectorL10n.authRegistrationRequestExplanation
        explanation2Label.textColor = theme.textPrimaryColor
        explanation2Label.text = VectorL10n.authRegistrationRequestExplanation2
        
        errorLabel.textColor = theme.warningColor
        errorLabel.text = ""
        errorLabel.isHidden = true
        
        firstNameTextField.attributedPlaceholder = NSAttributedString(string: VectorL10n.authRegistrationRequestFirstNamePlaceholder,
                                                                      attributes: [.foregroundColor: theme.placeholderTextColor])
        lastNameTextField.attributedPlaceholder = NSAttributedString(string: VectorL10n.authRegistrationRequestLastNamePlaceholder,
                                                                     attributes: [.foregroundColor: theme.placeholderTextColor])
        emailTextField.attributedPlaceholder = NSAttributedString(string: VectorL10n.authEmailPlaceholder,
                                                                     attributes: [.foregroundColor: theme.placeholderTextColor])
        
        sendRequestButton.setTitle(VectorL10n.authRegistrationRequestSend, for: .normal)
        sendRequestButton.setTitle(VectorL10n.authRegistrationRequestSend, for: .highlighted)
        sendRequestButton.layer.cornerRadius = 5
        theme.applyStyle(onButton: sendRequestButton)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
        
        self.title = VectorL10n.authRegistrationRequestTitle
    }
    
    @objc private func close() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction private func sendRequest() {
        let firstName = firstNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lastName = lastNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        print("[RegistrationRequestViewController] Checking for empty text fields")
        
        // Check for empty fields
        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty else {
            print("[RegistrationRequestViewController] ERROR: At least 1 text field is empty")
            
            self.setErrorLabelText(text: VectorL10n.authRegistrationRequestErrorMissingInput)
            return
        }
        
        // Check for valid email address
        guard MXTools.isEmailAddress(email) else {
            print("[RegistrationRequestViewController] ERROR: Provided email address is invalid")
            
            self.setErrorLabelText(text: VectorL10n.authRegistrationRequestErrorInvalidEmail)
            return
        }
        
        print("[RegistrationRequestViewController] Building request")
        
        activityView.isHidden = false
        sendRequestButton.isEnabled = false
        progressView.progress = 0
        successLabel.text = ""
        errorLabel.text = ""
        
        bugReport?.appName = UserDefaults.standard.string(forKey: "bugReportApp")
        bugReport?.version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            bugReport?.build = "#" + build
        } else {
            bugReport?.build = VectorL10n.settingsConfigNoBuildInfo
        }
        
        bugReport?.deviceOS = UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        
        let text = "Neue Anfrage!\n\nName: \(firstName) \(lastName)\nEmail Adresse: \(email)"
        
        // Closure need to get a strong reference to self so we receive callbacks
        let send: () -> Void = {
            [weak self] in
            // assign unwrapped optional to another variable
            guard let strongSelf: RegistrationRequestViewController = self  else {
                print("[RegistrationRequestViewController] ERROR: There was an error strongifying self.")
                
                self?.setErrorLabelText(text: VectorL10n.authRegistrationRequestErrorGeneric)
                return
            }
            
            // Sending request as a bug report
            strongSelf.bugReport?.sendBugReport(text, sendLogs: false, sendCrashLog: false, sendFiles: nil, attachGitHubLabels: nil, progress: { (bugReportState, progress) in
                // Update progress bar
                if let progress = progress {
                    strongSelf.progressView.progress = Float(progress.fractionCompleted)
                }
            }, success: {
                print("[RegistrationRequestViewController] Sending request successfull! Dismissing ViewController...")
                
                // Wait 1 second so the user can read the success message
                strongSelf.successLabel.text = VectorL10n.authRegistrationRequestSuccess
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    strongSelf.close()
                })
            }, failure: { (error) in
                strongSelf.activityView.isHidden = true
                if let error = error {
                    strongSelf.setErrorLabelText(text: error.localizedDescription)
                    
                    print("[RegistrationRequestViewController] Sending request failed! \(error.localizedDescription)")
                }
                
                strongSelf.sendRequestButton.isEnabled = true
            })
        }
        
        // Run closure
        send()
    }
    
    private func setErrorLabelText(text: String) {
        errorLabel.isHidden = false
        errorLabel.text = text
    }
}

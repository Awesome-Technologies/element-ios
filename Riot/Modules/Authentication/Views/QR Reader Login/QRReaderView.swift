//
//  QRReaderViewController.swift
//  Riot
//
//  Created by Marco Festini on 29.05.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit
import Firebase
import AVFoundation

class QRReaderView: MXKAuthInputsView, AVCaptureVideoDataOutputSampleBufferDelegate {
    @objc weak var qrReaderDelegate: QRReaderViewDelegate?
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var qrCodeInfoLabel: UILabel!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var cameraPermissionLabel: UILabel!
    @IBOutlet weak var cameraPermissionButton: UIButton!
    @IBOutlet weak var torchToggleButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var previewViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var qrInfoVerticalConstraint: NSLayoutConstraint!
    
    let keyText = "wo9k5tep252qxsa5yde7366kugy6c01w7oeeya9hrmpf0t7ii7"
    
    var session = AVCaptureSession()
    var currentCaptureDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var kvoTorchAvailabilityObserver: NSKeyValueObservation?
    var kvoTorchActiveStateObserver: NSKeyValueObservation?
    
    var inputsAlert: UIAlertController?
    
    let loginFoundBorderColor = UIColor(red: 0.23, green: 0.8, blue: 0.47, alpha: 1).cgColor
    let noLoginFoundBorderColor = UIColor(white: 1, alpha: 0.3).cgColor
    
    var foundLoginParameters: Bool = false {
        didSet {
            if foundLoginParameters {
                self.previewLayer?.borderColor = loginFoundBorderColor
            } else {
                self.previewLayer?.borderColor = noLoginFoundBorderColor
            }
        }
    }
    
    var isDetectBlocked = false
    
    private var qrUsername = ""
    private var qrPassword = ""
    private var qrToken = ""
    
    @objc dynamic override var userId: String! {
        return qrUsername
    }
    
    @objc dynamic override var password: String! {
        return qrPassword
    }
    
    @objc dynamic var token: String! {
        return qrToken
    }
    
    @objc class func fromNib() -> QRReaderView {
        if let nibArray = Bundle.main.loadNibNamed(String(describing: QRReaderView.self), owner: nil, options: nil) {
            if let result = nibArray[0] as? QRReaderView {
                return result
            }
        }
        return QRReaderView()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        
        // Calculate ratio taking into account smallest supported device (iPhone 4s)
        // and biggest supported device (iPhone Xs Max)
        
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            let screenSize: CGRect = UIScreen.main.bounds
            let screenHeight = screenSize.height
            let adjustedHeight = max(min((screenHeight - 480) / 115, 1.0), 0.4)
            let newWidthConstant = adjustedHeight * 220
            previewViewWidthConstraint?.constant = newWidthConstant
            qrInfoVerticalConstraint?.constant = 10
        default:
            previewViewWidthConstraint?.constant = 0
            qrInfoVerticalConstraint?.constant = 80
        }
    }
    
    @IBAction private func onOpenSettingsButtonPressed(_ sender: Any) {
        checkCameraAccess { granted in
            if !granted, let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    @IBAction private func onToggleTorchPressed(_ sender: Any) {
        if let device = currentCaptureDevice {
            toggleTorch(on: !device.isTorchActive)
        }
    }
    
    deinit {
        kvoTorchActiveStateObserver?.invalidate()
        kvoTorchAvailabilityObserver?.invalidate()
        toggleTorch(on: false)
    }
    
    // MARK: Layout & UI
    
    override func awakeFromNib() {
        self.qrCodeInfoLabel.text = VectorL10n.authQrTitle
        self.cameraPermissionLabel.text = VectorL10n.authQrNoPermission
        self.cameraPermissionButton.setTitle(VectorL10n.authQrAuthorize, for: .normal)
        self.cameraPermissionButton.setTitle(VectorL10n.authQrAuthorize, for: .highlighted)
        
        self.qrCodeInfoLabel.textColor = ThemeService.shared().theme.textPrimaryColor
        self.qrCodeImageView.tintColor = ThemeService.shared().theme.textPrimaryColor
        self.cameraPermissionLabel.textColor = ThemeService.shared().theme.textPrimaryColor
        self.activityIndicator.color = ThemeService.shared().theme.textPrimaryColor
        
        self.cameraPermissionButton.backgroundColor = ThemeService.shared().theme.baseColor
        self.cameraPermissionButton.setTitleColor(ThemeService.shared().theme.baseTextPrimaryColor, for: .normal)
        self.cameraPermissionButton.layer.cornerRadius = 5
        self.cameraPermissionButton.clipsToBounds = true
        
        self.torchToggleButton.isHidden = true
        self.torchToggleButton.tintColor = ThemeService.shared().theme.textPrimaryColor
        
        checkCameraAccess()
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        
        previewLayer?.frame = self.previewView.bounds
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let connection =  self.previewLayer?.connection {
            let currentDevice: UIDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection: AVCaptureConnection = connection
            
            if previewLayerConnection.isVideoOrientationSupported {
                switch orientation {
                case .portrait:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                case .landscapeRight:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                case .landscapeLeft:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                case .portraitUpsideDown:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                    
                default:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                }
            }
        }
    }
    
    @objc func willHide() {
        toggleTorch(on: false)
    }
    
    fileprivate func updateFlashIcon(_ isActive: Bool) {
        var flashIcon: UIImage
        
        if isActive {
            flashIcon = Asset.Images.flashOn.image
        } else {
            flashIcon = Asset.Images.flashOff.image
        }
        
        self.torchToggleButton.setImage(flashIcon, for: .normal)
    }
    
    // MARK: Camera
    
    @objc func unblock(timer: Timer) {
        isDetectBlocked = false
    }
    
    fileprivate func toggleTorch(on: Bool) {
        if !(currentCaptureDevice?.isTorchAvailable ?? false) {
            return
        }
        do {
            try currentCaptureDevice?.lockForConfiguration()
            currentCaptureDevice?.torchMode = on ? .on : .off
            currentCaptureDevice?.unlockForConfiguration()
            
        } catch {
            print(error)
        }
    }
    
    func checkCameraAccess(completion: ((Bool) -> Void)? = nil) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            self.setupCamera()
            completion?(true)
            self.cameraPermissionLabel.isHidden = true
            self.cameraPermissionButton.isHidden = true
            self.qrCodeInfoLabel.isHidden = false
            updateConstraints()
            
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                // UI relevant code must be called in main thread
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera()
                    }
                    self.cameraPermissionLabel.isHidden = granted
                    self.cameraPermissionButton.isHidden = granted
                    self.qrCodeInfoLabel.isHidden = !granted
                    
                    completion?(granted)
                    self.updateConstraints()
                }
            }
        default:
            completion?(false)
            self.cameraPermissionLabel.isHidden = false
            self.cameraPermissionButton.isHidden = false
            self.qrCodeInfoLabel.isHidden = true
            updateConstraints()
        }
    }
    
    func setupCamera() {
        // Capture Device
        if let device = AVCaptureDevice.default(for: AVMediaType.video) {
            do {
                currentCaptureDevice = device
                self.activityIndicator.startAnimating()
                
                // Observer torch active state
                kvoTorchActiveStateObserver?.invalidate()
                kvoTorchActiveStateObserver = device.observe(\.isTorchActive, options: [.new], changeHandler: { (device, change) in
                    if let isActive = change.newValue {
                        self.updateFlashIcon(isActive)
                    }
                })
                updateFlashIcon(device.isTorchActive)
                
                // Observer torch availability
                kvoTorchAvailabilityObserver?.invalidate()
                kvoTorchAvailabilityObserver = device.observe(\.isTorchAvailable, options: [.new], changeHandler: { (device, change) in
                    if let isAvailable = change.newValue {
                        self.torchToggleButton.isHidden = !isAvailable
                    }
                })
                
                let input = try AVCaptureDeviceInput(device: device)
                session.addInput(input)
                
                // Async init of capture start to avoid block ui thread
                DispatchQueue(label: "SessionInit").async {
                    
                    // Output
                    let output = AVCaptureVideoDataOutput()
                    output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutput"))
                    self.session.addOutput(output)
                    
                    self.session.startRunning()
                    
                    DispatchQueue.main.async {
                        // Preview Layer
                        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                        self.previewLayer?.videoGravity = .resizeAspectFill
                        self.previewLayer?.frame = self.previewView.bounds
                        self.previewLayer?.cornerRadius = 10
                        self.previewLayer?.borderColor = self.noLoginFoundBorderColor
                        self.previewLayer?.borderWidth = 3
                        self.previewView?.layer.addSublayer(self.previewLayer!)
                        
                        self.torchToggleButton.isHidden = !device.isTorchAvailable
                        
                        // Prevent checking every frame for QR Codes
                        Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.unblock(timer:)), userInfo: nil, repeats: true)
                        
                        self.activityIndicator.stopAnimating()
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isDetectBlocked || foundLoginParameters {
            return
        }
        isDetectBlocked = true
        
        let metadata = VisionImageMetadata()
        
        // Using back-facing camera
        let devicePosition: AVCaptureDevice.Position = .back
        
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portrait:
            metadata.orientation = devicePosition == .front ? .leftTop : .rightTop
        case .landscapeLeft:
            metadata.orientation = devicePosition == .front ? .bottomLeft : .topLeft
        case .portraitUpsideDown:
            metadata.orientation = devicePosition == .front ? .rightBottom : .leftBottom
        case .landscapeRight:
            metadata.orientation = devicePosition == .front ? .topRight : .bottomRight
        case .faceDown, .faceUp, .unknown:
            metadata.orientation = .leftTop
        }
        
        let image = VisionImage(buffer: sampleBuffer)
        image.metadata = metadata
        
        let format = VisionBarcodeFormat.qrCode
        let barcodeOptions = VisionBarcodeDetectorOptions(formats: format)
        
        let vision = Vision.vision()
        let barcodeDetector = vision.barcodeDetector(options: barcodeOptions)
        
        barcodeDetector.detect(in: image) { (features, error) in
            guard error == nil, let features = features, !features.isEmpty else {
                return
            }
            let loginURL = features.first?.rawValue
            if var server = UserDefaults.standard.string(forKey: "homeserverurl") {
                // Check for proper suffix of homeserver url
                server += server.last == "/" ? "#" : "/#"
                
                if !self.foundLoginParameters && loginURL?.starts(with: server) ?? false {
                    if let base64String = loginURL?.suffix(from: server.endIndex) {
                        
                        // Use result to decode from BASE64
                        if let base64Data = Data(base64Encoded: String(base64String)) {
                            if let decodedString = String(data: base64Data, encoding: .utf8) {
                                
                                // Perform XOR with cipher
                                if let params = self.performXOR(cipherText: [UInt8](decodedString.utf8)) {
                                    
                                    self.checkParameters(params)
                                }
                            }
                        }
                    }
                    
                }
            }
        }
    }
    
    // MARK: Authentication
    
    fileprivate func checkParameters(_ params: String) {
        // Check for Username & Password
        var pattern = "^user=(?<username>[\\S]+)&password=(?<password>[\\S]+)+$"
        var regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        if let match = regex?.firstMatch(in: params, options: [], range: NSRange(location: 0, length: params.count)) {
            var validParameters = true
            
            if let usernameRange = Range(match.range(at: 1), in: params) {
                self.qrUsername = String(params[usernameRange])
            } else {
                validParameters = false
            }
            
            if let passwordRange = Range(match.range(at: 2), in: params) {
                self.qrPassword = String(params[passwordRange])
            } else {
                validParameters = false
            }
            
            if validParameters {
                print("[QRReaderView] Found Username & Password")
                self.foundLoginParameters = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.qrReaderDelegate?.onFoundLoginParameters(username: self.userId, password: self.password)
                }
            }
        }
        
        // Check for Token
        pattern = "^token=(?<token>[\\S]+)$"
        regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        if let match = regex?.firstMatch(in: params, options: [], range: NSRange(location: 0, length: params.count)) {
            var validParameters = true
            
            if let tokenRange = Range(match.range(at: 2), in: params) {
                self.qrToken = String(params[tokenRange])
            } else {
                validParameters = false
            }
            
            if validParameters {
                print("[QRReaderView] Found Token. This login type is currently not supported")
                // Not yet supported
            }
        }
    }
    
    override func validateParameters() -> String! {
        self.qrUsername = self.qrUsername.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        self.qrPassword = self.qrPassword.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        self.qrToken = self.qrToken.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        return nil
    }
    
    override func prepareParameters(_ callback: (([AnyHashable: Any]?, Error?) -> Void)!) {
        if callback == nil {
            return
        }
        
        var parameters: [String: Any] = [:]
        
        // Check the validity of the parameters
        let errorMsg = validateParameters()
        if errorMsg?.isEmpty ?? false {
            
            inputsAlert?.dismiss(animated: false, completion: nil)
            
            inputsAlert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "error"), message: errorMsg, preferredStyle: .alert)
            
            inputsAlert?.addAction(UIAlertAction(title: Bundle.mxk_localizedString(forKey: "ok"), style: .default, handler: { action in
                self.inputsAlert = nil
            }))
            
            self.delegate.authInputsView(self, present: inputsAlert)
        } else if self.authType == MXKAuthenticationTypeLogin {
            parameters = ["type": kMXLoginFlowTypePassword,
                              "identifier": ["type": kMXLoginIdentifierTypeUser,
                                             "user": self.qrUsername],
                              "password": self.qrPassword,
                              "user": self.qrUsername]
        }
        
        callback(parameters, nil)
    }
    
    @objc func loginFailed() {
        self.foundLoginParameters = false
    }
    
    @objc func loginSuccessful() {
        toggleTorch(on: false)
    }
    
    // MARK: XOR
    
    func performXOR(cipherText: [UInt8]) -> String? {
        if cipherText.count == 0 { return "" }
        
        var decrypted = [UInt8]()
        let cipher = cipherText
        let key = [UInt8](keyText.utf8)
        let length = key.count
        
        // decrypt bytes
        for c in cipher.enumerated() {
            decrypted.append(c.element ^ key[c.offset % length])
        }
        
        return String(bytes: decrypted, encoding: .utf8)
    }
}

//
//  AudioAttachmentView.swift
//  Riot
//
//  Created by Marco Festini on 12.06.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

/**
 Posted when another AudioAttachmentView tries to play audio.
 */
let kAudioAttachmentWillPlayAudioNotification: String = "kAudioAttachmentWillPlayAudioNotification"

class AudioAttachmentView: UIView, AVAudioPlayerDelegate {
    static var activePlayer: AudioAttachmentView?
    
    @IBOutlet var view: UIView!
    
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var playStopToggleButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var attachment: MXKAttachment!
    private var audioFileURL: URL = URL(fileURLWithPath: "")
    private var audioPlayer: AVAudioPlayer?
    private var timeSliderTimer: CADisplayLink?
    private var isScrubbing = false
    private var waitingForResponse = false
    
    fileprivate var kThemeServiceDidChangeThemeNotificationObserver: Any!
    fileprivate var kAudioSessionInterruptionNotificationObserver: Any!
    fileprivate var kApplicationWillResignActiveNotificationObserver: Any!
    fileprivate var kProximityStateNotificationObserver: Any!
    fileprivate var kAudioRouteChangeNotificationObserver: Any!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        UINib(nibName: "AudioAttachmentView", bundle: nil).instantiate(withOwner: self, options: nil)
        
        addSubview(view)
        view.frame = self.bounds
        self.backgroundColor = UIColor.clear
        
        setupNotifications()
        
        // Add tap gesture recognizer to View
        // Toggle playback
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(togglePlayback(_:)))
        view.addGestureRecognizer(tapGesture)
        
        updateInterfaceElements()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let isPlaying = audioPlayer?.isPlaying, isPlaying {
            pause()
        } else {
            AudioManager.shared().deactivateAudioSession()
        }
    }
    
    fileprivate func setupNotifications() {
        // Observe user interface theme change.
        kThemeServiceDidChangeThemeNotificationObserver = NotificationCenter.default.addObserver(forName: .themeServiceDidChangeTheme, object: nil, queue: OperationQueue.main) {_ in
            self.userIntferfaceThemeDidChange()
        }
        
        // Observe interruptions of AVAudioSession
        kAudioSessionInterruptionNotificationObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: OperationQueue.main) { (notification) in
            guard let userInfo = notification.userInfo,
                let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
            }
            if type == .began {
                self.pause()
            }
        }
        
        // Observe Application going into background
        kApplicationWillResignActiveNotificationObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: OperationQueue.main) {_ in
            self.pause()
        }
        
        // Observe change of proximity state
        kProximityStateNotificationObserver = NotificationCenter.default.addObserver(forName: UIDevice.proximityStateDidChangeNotification, object: nil, queue: OperationQueue.main) {_ in
            self.checkProximityState()
        }
        
        // Observe audio routing changes
        kAudioRouteChangeNotificationObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: OperationQueue.main) { (notification) in
            guard let userInfo = notification.userInfo,
                let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                    return
            }
            
            switch reason {
            case .oldDeviceUnavailable:
                self.pause()
            default: ()
            }
        }
    }
    
    @objc func setAttachment(_ attachment: MXKAttachment) {
        if self.attachment === attachment {
            return
        }
        self.attachment = attachment
        
        // Indicate pending loading of audio file
        // Disable playback until it's ready
        activityIndicator.startAnimating()
        playStopToggleButton.isEnabled = false
        timeSlider.isHidden = true
        
        attachment.prepare({
            if attachment.isEncrypted {
                attachment.decrypt(toTempFile: { fileName in
                    if let name = fileName {
                        self.audioFileURL = URL(fileURLWithPath: name)
                        DispatchQueue.main.async {
                            self.prepateToPlay()
                        }
                    }
                }, failure: { error in
                    self.activityIndicator.stopAnimating()
                    print("\(#function)")
                    
                    if let errorDescription = error?.localizedDescription {
                        print(errorDescription)
                    }
                })
            } else {
                self.audioFileURL = URL(fileURLWithPath: attachment.cacheFilePath)
                DispatchQueue.main.async {
                    self.prepateToPlay()
                }
            }
        }, failure: { error in
            self.activityIndicator.stopAnimating()
            print("\(#function)")
            
            if let errorDescription = error?.localizedDescription {
                print(errorDescription)
            }
        })
    }
    
    // MARK: - User Interface
    
    private func userIntferfaceThemeDidChange() {
        playStopToggleButton.imageView?.tintColor = ThemeService.shared().theme.textPrimaryColor
        durationLabel.textColor = ThemeService.shared().theme.textPrimaryColor
        activityIndicator.color = ThemeService.shared().theme.textPrimaryColor
        
        var thumbColor = ThemeService.shared().theme.textSecondaryColor
        
        if audioPlayer?.isPlaying ?? false || isScrubbing {
            thumbColor = ThemeService.shared().theme.textTintColor
        }
        
        if let audioSliderThumb = circle(diameter: 14, color: thumbColor) {
            timeSlider.setThumbImage(audioSliderThumb, for: .normal)
        }
        
        timeSlider.minimumTrackTintColor = ThemeService.shared().theme.textTintColor
        timeSlider.maximumTrackTintColor = ThemeService.shared().theme.textPrimaryColor
    }
    
    private func circle(diameter: CGFloat, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0)
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.saveGState()
            
            let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: rect)
            
            ctx.restoreGState()
            if let img = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                
                return img
            }
        }
        return nil
    }
    
    private func updateInterfaceElements() {
        if audioPlayer != nil {
            if audioPlayer?.isPlaying ?? false, let currentTime = audioPlayer?.currentTime {
                playStopToggleButton.setImage(Asset.Images.pauseAudio.image, for: .normal)
                timeSlider.setValue(Float(currentTime), animated: true)
            } else {
                playStopToggleButton.setImage(Asset.Images.playAudio.image, for: .normal)
            }
            durationLabel.text = audioPlayerTimeToString()
        } else {
            durationLabel.text = ""
        }
        
        userIntferfaceThemeDidChange()
    }
    
    private func audioPlayerTimeToString() -> String! {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        if let currentTime = audioPlayer?.currentTime, let duration = audioPlayer?.duration, let currentTimeFormatted = formatter.string(from: currentTime), let durationFormatted = formatter.string(from: duration) {
            return currentTimeFormatted + " / " + durationFormatted
        } else {
            return "00:00 / 00:00"
        }
    }
    
    @objc func updateTimeSliderDuringPlayback() {
        guard audioPlayer?.isPlaying == true else {
            return
        }
        if let currentTime = audioPlayer?.currentTime {
            timeSlider.setValue(Float(currentTime), animated: true)
            durationLabel.text = audioPlayerTimeToString()
        }
    }
    
    @IBAction private func timeSliderValueChanged(_ sender: Any) {
        guard audioPlayer?.isPlaying == false else {
            return
        }
        audioPlayer?.currentTime = TimeInterval(timeSlider.value)
        durationLabel.text = audioPlayerTimeToString()
    }
    
    // MARK: - User Interaction
    
    @IBAction private func startScrubbing(_ sender: Any) {
        if audioPlayer?.isPlaying ?? false {
            audioPlayer?.stop()
            timeSliderTimer?.isPaused = true
        }
        
        isScrubbing = true
        
        updateInterfaceElements()
    }
    
    @IBAction private func stopScrubbing(_ sender: Any) {
        isScrubbing = false
        
        updateInterfaceElements()
    }
    
    @IBAction private func togglePlayback(_ sender: Any) {
        if audioPlayer?.isPlaying ?? false {
            pause()
        } else {
            play()
        }
    }
    
    // MARK: - Audio Playback
    
    func prepateToPlay() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.delegate = self
            
            if let duration = audioPlayer?.duration {
                timeSlider.maximumValue = Float(duration)
            }
            timeSlider.setValue(0, animated: false)
            playStopToggleButton.isEnabled = true
            timeSlider.isHidden = false
            
            activityIndicator.stopAnimating()
            
            updateInterfaceElements()
            
            print("\(#function) Audio player prepared")
        } catch let error as NSError {
            activityIndicator.stopAnimating()
            print("\(#function)")
            
            print("\(error.localizedDescription)")
        }
    }
    
    fileprivate func play() {
        guard audioPlayer?.isPlaying == false, playStopToggleButton.isEnabled else {
            return
        }
        
        AudioManager.shared().activateAudioSession(.playAndRecord, mode: .default, options: [.duckOthers], completion: {
            AudioAttachmentView.activePlayer?.pause()
            AudioRecorder.shared().pauseRecording()
            
            do {
                let session = AVAudioSession.sharedInstance()
                if (session.currentRoute.outputs.contains { $0.portType == .builtInReceiver }) && !UIDevice.current.proximityState {
                    try session.overrideOutputAudioPort(.speaker)
                }
                
                if self.audioPlayer?.play() ?? false {
                    if self.timeSliderTimer == nil {
                        self.timeSliderTimer = CADisplayLink(target: self, selector: #selector(self.updateTimeSliderDuringPlayback))
                        self.timeSliderTimer?.add(to: .current, forMode: .common)
                    } else {
                        self.timeSliderTimer?.isPaused = false
                    }
                    
                    AudioAttachmentView.activePlayer = self
                    self.activateMonitoring()
                    
                    self.updateInterfaceElements()
                }
            } catch let error as NSError {
                print("\(#function)")
                
                print("\(error.localizedDescription)")
            }
        })
    }
    
    func pause() {
        guard audioPlayer?.isPlaying == true else {
            return
        }
        print("\(#function) Pausing playback")
        audioPlayer?.stop()
        
        playingHasStopped()
    }
    
    func playingHasStopped() {
        timeSliderTimer?.isPaused = true
        
        AudioManager.shared().deactivateAudioSession()
        
        deactivateMonitoring()
        
        updateInterfaceElements()
    }
    
    // MARK: - Device Monitoring
    
    private func activateMonitoring() {
        print("\(#function) Activating proximity and route change monitoring")
        UIDevice.current.isProximityMonitoringEnabled = true
    }
    
    private func deactivateMonitoring() {
        print("\(#function) Deactivating proximity and route change monitoring")
        UIDevice.current.isProximityMonitoringEnabled = false
    }
    
    private func checkProximityState() {
        updateInterfaceElements()
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            let usingSpeaker = session.currentRoute.outputs.contains { $0.portType == .builtInSpeaker }
            let usingReceiver = session.currentRoute.outputs.contains { $0.portType == .builtInReceiver }
            
            if UIDevice.current.proximityState && usingSpeaker {
                try session.overrideOutputAudioPort(.none)
            } else if !UIDevice.current.proximityState && usingReceiver {
                pause()
            }
        } catch let error as NSError {
            print("\(#function)")
            
            print("\(error.localizedDescription)")
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer?.currentTime = 0
        timeSlider.setValue(0, animated: false)
        
        playingHasStopped()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("\(#function) decode error:")
        if let errorDescription = error?.localizedDescription {
            print(errorDescription)
        }
    }
}

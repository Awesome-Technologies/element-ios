//
//  AudioRecorder.swift
//  Riot
//
//  Created by Marco Festini on 11.06.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    var kAudioSessionInterruptionNotificationObserver: Any!
    var kAudioAttachmentWillPlayAudioNotificationObserver: Any!
    
    @objc weak var delegate: AudioRecorderDelegate?
    
    @objc var isRecordingOrPaused: Bool {
        if let recorder = audioRecorder, recorder.currentTime != 0 {
            return true
        }
        return false
    }
    
    @objc var isPaused: Bool {
        if let recorder = audioRecorder, isRecordingOrPaused, !recorder.isRecording {
            return true
        }
        return false
    }
    private var isCanceling: Bool = false
    private var roomId: String = ""
    
    @objc var recordingTimeString: String {
        if isRecordingOrPaused {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .positional
            formatter.zeroFormattingBehavior = .pad
            
            if let currentTime = audioRecorder?.currentTime, let currentTimeFormatted = formatter.string(from: TimeInterval(currentTime)) {
                return currentTimeFormatted
            } else {
                return "-"
            }
        } else {
            return "-"
        }
    }
    
    fileprivate static var sharedAudioRecorder: AudioRecorder = {
        return AudioRecorder()
    }()
    
    private override init() {
        super.init()
    }
    
    @objc class func shared() -> AudioRecorder {
        return sharedAudioRecorder
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func initRecorder() {
        if isRecordingOrPaused {
            return
        }
        
        if kAudioSessionInterruptionNotificationObserver == nil {
            // Observe interruptions of AVAudioSession
            kAudioSessionInterruptionNotificationObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: OperationQueue.main) { (notification) in
                guard let userInfo = notification.userInfo,
                    let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                    let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                        return
                }
                if type == .began {
                    self.pauseRecording()
                }
            }
        }
        
        let session = AVAudioSession.sharedInstance()
        print("\(#function) Check permission")
        switch session.recordPermission {
        case AVAudioSession.RecordPermission.granted:
            print("\(#function) Permission granted")
            microphoneAccessGranted()
            
        case AVAudioSession.RecordPermission.denied:
            print("\(#function) Pemission denied")
            microphoneAccessDenied()
            
        case AVAudioSession.RecordPermission.undetermined:
            print("\(#function) Requesting permission")
            
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                if granted {
                    self.microphoneAccessGranted()
                } else {
                    self.microphoneAccessDenied()
                }
            })
        }
    }
    
    @objc func check(roomId newRoomId: String) {
        if roomId != newRoomId {
            cancelRecording(forceCancel: true)
        }
        roomId = newRoomId
    }
    
    // MARK: - Permission
    
    fileprivate func microphoneAccessDenied() {
        let alertController = UIAlertController(title: VectorL10n.noMicrophoneAccessTitle, message: VectorL10n.noMicrophoneAccessMessage, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: VectorL10n.cancel, style: .cancel, handler: nil)
        
        let settingsAction = UIAlertAction(title: VectorL10n.settingsTitle, style: .default) {_ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.openURL(url)
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)
        
        delegate?.presentAlertController(alertController)
    }
    
    fileprivate func microphoneAccessGranted() {
        prepareRecorder()
        startRecording()
    }
    
    // MARK: - Audio Recording
    
    @objc func prepareRecorder() {
        guard isRecordingOrPaused == false else {
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            
            if session.recordPermission != .granted {
                return
            }
            
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentsDirectory = paths[0]
            let soundFileURL = documentsDirectory.appendingPathComponent("VoiceMessage.aac")
            
            if FileManager.default.fileExists(atPath: soundFileURL.absoluteString) {
                try FileManager.default.removeItem(atPath: soundFileURL.absoluteString)
            }
            
            let recordSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue]
            
            audioRecorder = try AVAudioRecorder(url: soundFileURL, settings: recordSettings)
            audioRecorder?.delegate = self
            
            print("\(#function)")
        } catch let error as NSError {
            print("\(#function)")
            
            print("\(error.localizedDescription)")
        }
    }
    
    @objc func startRecording() {
        if isRecordingOrPaused && !isPaused {
            return
        }
        
        AudioManager.shared().activateAudioSession(.playAndRecord, mode: .default, options: [.duckOthers], completion: {
            AudioAttachmentView.activePlayer?.pause()
            
            if self.audioRecorder?.record() ?? false {
                print("\(#function)")
                
                self.isCanceling = false
                DispatchQueue.main.async {
                    self.delegate?.voiceRecordingDidStartRecording()
                }
            }
        })
    }
    
    @objc func togglePauseRecording() {
        if isPaused {
            startRecording()
        } else {
            pauseRecording()
        }
    }
    
    @objc func pauseRecording() {
        if isPaused || !isRecordingOrPaused {
            return
        }
        print("\(#function)")
        audioRecorder?.pause()
        DispatchQueue.main.async {
            self.delegate?.voiceRecordingDidPauseRecording()
        }
        
        AudioManager.shared().deactivateAudioSession()
    }
    
    @objc func stopRecording() {
        if isRecordingOrPaused {
            print("\(#function)")
            audioRecorder?.stop()
        }
    }
    
    @objc func cancelRecording(forceCancel: Bool = false) {
        print("\(#function)")
        if !isRecordingOrPaused {
            return
        }
        
        if forceCancel {
            self.isCanceling = true
            self.stopRecording()
            return
        }
        
        let alertController = UIAlertController(title: VectorL10n.cancelVoiceRecordingTitle, message: VectorL10n.cancelVoiceRecordingMessage, preferredStyle: .alert)
        
        let closeAction = UIAlertAction(title: VectorL10n.close, style: .cancel)
        
        let cancelAction = UIAlertAction(title: VectorL10n.cancel, style: .default) {_ in
            self.isCanceling = true
            self.stopRecording()
        }
        
        alertController.addAction(closeAction)
        alertController.addAction(cancelAction)
        
        DispatchQueue.main.async {
            self.delegate?.presentAlertController(alertController)
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if isCanceling {
            audioRecorder?.deleteRecording()
            DispatchQueue.main.async {
                self.delegate?.voiceRecordingDidStopRecording()
            }
        } else if flag {
            DispatchQueue.main.async {
                self.delegate?.voiceRecordingDidFinishRecording(withURL: recorder.url)
            }
        }
        
        audioRecorder = nil
        AudioManager.shared().deactivateAudioSession()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder,
                                          error: Error?) {
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.delegate?.voiceRecordingDidStopRecording()
        }
        
        AudioManager.shared().deactivateAudioSession()
        
        if let e = error {
            print("\(#function)")
            
            print("\(e.localizedDescription)")
        }
    }
}

//
//  AudioManager.swift
//  Riot
//
//  Created by Marco Festini on 18.06.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class AudioManager: NSObject {
    private var activeCount = 0
    private var kMXCallStateDidChangeObserver: Any!
    
    fileprivate static var sharedAudioManager: AudioManager = {
        return AudioManager()
    }()
    
    private override init() {
        super.init()
        // Observe call state to pause everything should a jitsi call come in
        kMXCallStateDidChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: kMXCallStateDidChange), object: nil, queue: .main) {notification in
            if let call = notification.object as? MXCall {
                if call.isIncoming && call.state == MXCallState.waitLocalMedia {
                    self.pauseAllPlayersAndRecorders()
                }
            }
        }
    }
    
    @objc class func shared() -> AudioManager {
        return sharedAudioManager
    }
    
    func activateAudioSession(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions = [], completion:@escaping () -> (Void)) {
        activeCount += 1
        print("\(#function) " + activeCount.description)
        if activeCount > 1 {
            DispatchQueue.main.async {
                completion()
            }
            print("\(#function) Already active audio session. Skipping...")
            return
        }
        DispatchQueue(label: "AudioSession").async {
            do {
                let session = AVAudioSession.sharedInstance()
                
                if #available(iOS 10.0, *) {
                    try session.setCategory(category, mode: mode, options: options)
                } else {
                    // Workaround until https://forums.swift.org/t/using-methods-marked-unavailable-in-swift-4-2/14949 isn't fixed
                    session.perform(NSSelectorFromString("setCategory:error:"), with: category)
                }
                
                try session.setActive(true)
                DispatchQueue.main.async {
                    completion()
                }
            } catch let error as NSError {
                print("\(#function)")
                
                print("\(error.localizedDescription)")
            }
        }
    }
    
    func deactivateAudioSession() {
        activeCount -= 1
        
        print("\(#function) " + activeCount.description)
        if activeCount > 0 {
            print("\(#function) More than 1 remaining audio sessions. Skipping...")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            
            try session.overrideOutputAudioPort(.none)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch let error as NSError {
            print("\(#function)")
            
            print("\(error.localizedDescription)")
        }
    }
    
    @objc func pauseAllPlayersAndRecorders() {
        AudioAttachmentView.activePlayer?.pause()
        AudioRecorder.shared().pauseRecording()
    }
}

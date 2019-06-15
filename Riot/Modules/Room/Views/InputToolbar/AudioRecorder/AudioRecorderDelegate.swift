//
//  AudioRecorderDelegate.swift
//  Riot
//
//  Created by Marco Festini on 11.06.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import Foundation

@objc protocol AudioRecorderDelegate {
    @objc func voiceRecordingDidStartRecording()
    @objc func voiceRecordingDidPauseRecording()
    @objc func voiceRecordingDidFinishRecording(withURL url: URL)
    @objc func voiceRecordingDidStopRecording()
    @objc func presentAlertController(_ alertController: UIAlertController!)
}

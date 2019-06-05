//
//  QRReaderViewDelegate.swift
//  Riot
//
//  Created by Marco Festini on 29.05.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import Foundation

@objc protocol QRReaderViewDelegate: class {
    @objc func onFoundLoginParameters(username: String, password: String)
}

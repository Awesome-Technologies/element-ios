//
//  EditingView.swift
//  Riot
//
//  Created by Marco Festini on 18.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

protocol EditingView {
    var delegate: RowEditingDelegate! { get set }
    var currentRow: Row! { get set }
    
    func setInitialData(_ data: (value: Any?, date: Date?), showDate: Bool)
    func setPlaceholder(_ string: String?)
}

// Added to make functions optional
extension EditingView {
    func setInitialData(_ data: (value: Any?, date: Date?), showDate: Bool) {}
    func setPlaceholder(_ string: String?) {}
}

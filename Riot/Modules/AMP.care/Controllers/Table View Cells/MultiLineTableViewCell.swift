//
//  MultiLineTableViewCell.swift
//  Riot
//
//  Created by Marco Festini on 18.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class MultiLineTableViewCell: UITableViewCell {
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var textViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightLabelTrailingConstraint: NSLayoutConstraint!
    
    static func defaultReuseIdentifier() -> String {
        return String(describing: self)
    }
    
    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        
        if key == "accessoryType" {
            updateConstraints()
        }
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        
        if accessoryType == .none {
            textViewTrailingConstraint.constant = 20
            rightLabelTrailingConstraint.constant = 20
        } else {
            textViewTrailingConstraint.constant = 0
            rightLabelTrailingConstraint.constant = 0
        }
    }
}

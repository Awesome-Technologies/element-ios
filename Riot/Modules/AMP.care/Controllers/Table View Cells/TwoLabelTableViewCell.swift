//
//  TwoLabelTableViewCell.swift
//  Riot
//
//  Created by Marco Festini on 17.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class TwoLabelTableViewCell: UITableViewCell {
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightTopLabel: UILabel!
    @IBOutlet weak var rightBottomLabel: UILabel!
    
    @IBOutlet weak var rightTopTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightBottomTrailingConstraint: NSLayoutConstraint!
    
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
            rightTopTrailingConstraint.constant = 20
            rightBottomTrailingConstraint.constant = 20
        } else {
            rightTopTrailingConstraint.constant = 0
            rightBottomTrailingConstraint.constant = 0
        }
    }
}

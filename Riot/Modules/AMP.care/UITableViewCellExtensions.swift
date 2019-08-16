//
//  UITableViewCellExtensions.swift
//  Riot
//
//  Created by Marco Festini on 24.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import Foundation

public extension UITableViewCell {
    @objc static func nib() -> UINib {
        return UINib(nibName: String(describing: self), bundle: nil)
    }
}

public extension UICollectionViewCell {
    @objc static func nib() -> UINib {
        return UINib(nibName: String(describing: self), bundle: nil)
    }
}

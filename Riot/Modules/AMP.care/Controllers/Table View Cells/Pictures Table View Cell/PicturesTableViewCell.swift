//
//  PicturesTableViewCell.swift
//  Riot
//
//  Created by Marco Festini on 25.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class PicturesTableViewCell: UITableViewCell {
    @IBOutlet weak var collectionView: DynamicHeightCollectionView!
    
    static func defaultReuseIdentifier() -> String {
        return String(describing: self)
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.collectionViewLayout.prepare()
        collectionView.setNeedsLayout()
        collectionView.layoutIfNeeded()
    }
}

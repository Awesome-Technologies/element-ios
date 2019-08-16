//
//  PicturesDelegate.swift
//  Riot
//
//  Created by Marco Festini on 25.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

protocol PicturesDelegate: class {
    func getPictures() -> [UIImage]
}

protocol PicturesEditDelegate: PicturesDelegate {
    func addedPicture(_ image: UIImage)
    func removedPicture(at position: Int)
}

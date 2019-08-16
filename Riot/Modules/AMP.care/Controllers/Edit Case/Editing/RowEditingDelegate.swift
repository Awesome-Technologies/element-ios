//
//  RowEditingDelegate.swift
//  Riot
//
//  Created by Marco Festini on 18.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

protocol RowEditingDelegate: class {
    func finishedEditing(ofRow row: Row, result: Any?)
}

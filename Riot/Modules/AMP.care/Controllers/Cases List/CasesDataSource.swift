//
//  CasesDataSource.swift
//  Riot
//
//  Created by Marco Festini on 27.03.20.
//  Copyright © 2020 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class CasesDataSource: MXKRecentsDataSource {
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

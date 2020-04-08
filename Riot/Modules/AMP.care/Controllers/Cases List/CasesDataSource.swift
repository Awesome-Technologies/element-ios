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
    
    // Automatically join any room the user is invited to
    override func dataSource(_ dataSource: MXKDataSource!, didCellChange changes: Any!) {
        if let recentsDataSourceArray = value(forKey: "displayedRecentsDataSourceArray") as? [MXKSessionRecentsDataSource], recentsDataSourceArray.count > 0 {
            
            let recentsDataSource = recentsDataSourceArray[0]
            let numberOfCells = recentsDataSource.numberOfCells
            for cellIndex in 0..<numberOfCells {
                let cell = recentsDataSource.cellData(at: cellIndex)
                if cell?.roomSummary.membership == .invite {
                    cell?.roomSummary.room.join(completion: { response in
                        if response.isFailure, let error = response.error {
                            print("CasesDataSource: init - Error joining room %@", error.localizedDescription)
                        }
                    })
                }
            }
        }
        
        super.dataSource(dataSource, didCellChange: changes)
    }
}

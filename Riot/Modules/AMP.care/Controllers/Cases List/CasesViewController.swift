//
//  CasesViewController.swift
//  Riot
//
//  Created by Marco Festini on 10.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class CasesViewController: MXKRecentListViewController, MXKRecentListViewControllerDelegate {
    
    private var newCaseNavigationController: UINavigationController!
    @IBOutlet private weak var newCaseButton: UIButton!
    
    @objc override class func nib() -> UINib {
        return UINib(nibName: String(describing: self), bundle: nil)
    }
    
    @objc class func fromNib() -> CasesViewController {
        let vc = CasesViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = vc.view
        return vc
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        themeDidChange()
        
        AppDelegate.the()?.masterTabBarController?.navigationItem.title = NSLocalizedString("case_list_title", tableName: "AMPcare", comment: "")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if recentsTableView == nil {
            CasesViewController.nib().instantiate(withOwner: self, options: nil)
        }
        
        // Do any additional setup after loading the view.
        self.recentsTableView.register(CaseTableViewCell.nib(), forCellReuseIdentifier: CaseTableViewCell.defaultReuseIdentifier())
        self.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: .themeServiceDidChangeTheme, object: nil)
        themeDidChange()
        
        newCaseButton.setTitle(NSLocalizedString("new_case_button", tableName: "AMPcare", comment: ""), for: .normal)
    }
    
    @objc func themeDidChange() {
        if let navBar = self.navigationController?.navigationBar {
            ThemeService.shared().theme.applyStyle(onNavigationBar: navBar)
        }
        ThemeService.shared().theme.applyStyle(onButton: newCaseButton)
    }
    
    override func cellViewClass(for cellData: MXKCellData!) -> MXKCellRendering.Type! {
        return CaseTableViewCell.self
    }
    
    override func cellReuseIdentifier(for cellData: MXKCellData!) -> String! {
        return CaseTableViewCell.defaultReuseIdentifier()
    }
    
    // MARK: - User Interface
    
    @IBAction private func newCase(_ sender: Any) {
        let vc = CaseEditViewController.fromNib()
        
        if let session = self.mxSessions.first as? MXSession {
            vc.session = session
        }
        
        newCaseNavigationController = UINavigationController(rootViewController: vc)
        newCaseNavigationController.modalPresentationStyle = .formSheet
        vc.setupHeader()
        
        self.present(newCaseNavigationController, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return nil
    }
    
    // MARK: - MXKRecentListViewControllerDelegate
    
    func recentListViewController(_ recentListViewController: MXKRecentListViewController!, didSelectRoom roomId: String!, inMatrixSession mxSession: MXSession!) {
        print("didSelectRoom")
        
        AppDelegate.the()?.masterTabBarController?.selectRoom(withId: roomId, andEventId: nil, inMatrixSession: mxSession)
    }
}

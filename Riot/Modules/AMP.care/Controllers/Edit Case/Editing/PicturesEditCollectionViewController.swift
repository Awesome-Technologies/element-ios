//
//  PicturesEditCollectionViewController.swift
//  Riot
//
//  Created by Marco Festini on 19.07.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

import UIKit

class PicturesEditCollectionViewController: UICollectionViewController, EditingView, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var currentRow: Row!
    weak var delegate: RowEditingDelegate!
    weak var picturesDelegate: PicturesEditDelegate! {
        didSet {
            self.collectionView.reloadData()
        }
    }
    
    private let reuseIdentifier = "ImageCell"
    
    private let itemsPerRow: CGFloat = 3
    private let collectionInsets = UIEdgeInsets(top: 10.0,
                                                left: 15.0,
                                                bottom: 10.0,
                                                right: 15.0)
    private let padding: CGFloat = 15
    
    @objc class func fromNib() -> PicturesEditCollectionViewController {
        let result = PicturesEditCollectionViewController(nibName: String(describing: self), bundle: nil)
        // Force building view hierarchy so all ui bindings are in place
        _ = result.view
        return result
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
        var scrollInsets = collectionInsets
        scrollInsets.right = 0
        scrollInsets.left = 0
        self.collectionView.scrollIndicatorInsets = scrollInsets
        self.collectionView.contentInset = collectionInsets

        // Register cell class
        self.collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
        self.collectionView.alwaysBounceVertical = true
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(showCamera))
    }
    
    @objc func showCamera() {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera), UIImagePickerController.isCameraDeviceAvailable(.rear) {
            picker.sourceType = .camera
            picker.cameraDevice = .rear
            picker.delegate = self
            present(picker, animated: true)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) {
            if let image = info[.originalImage] as? UIImage {
                self.picturesDelegate.addedPicture(image)
                let indexPath = IndexPath(row: self.picturesDelegate.getPictures().count - 1, section: 0)
                self.collectionView.performBatchUpdates({
                    self.collectionView.insertItems(at: [indexPath])
                }, completion: { anim in
                    self.collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
                })
            }
        }
    }

    // MARK: - UICollectionViewDataSource

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return picturesDelegate.getPictures().count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        
        let view = UIImageView(image: picturesDelegate.getPictures()[indexPath.row])
        view.contentMode = .scaleAspectFit
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        view.frame = cell.bounds
        cell.addSubview(view)
    
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let paddingSpace = padding * (itemsPerRow - 1) + collectionInsets.left + collectionInsets.right
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return collectionInsets.left
    }
}

//
//  CameraViewController.swift
//  TLCameraFramework
//
//  Created by 刘腾 on 2019-08-19.
//  Copyright © 2019 Teng Liu. All rights reserved.
//

import UIKit
import AVFoundation

public final class TLCameraViewController: UIViewController {
    var camera: TLCamera?
    var previewImageView: UIImageView!
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .lightGray
    }
    
    @objc func capturePhoto() {
        self.camera?.capturePhoto()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        camera = TLCamera(withController: self)
        camera?.delegate = self
        self.previewImageView = {
            let view = UIImageView(frame: self.view.bounds)
            view.backgroundColor = .darkGray
            view.contentMode = .scaleAspectFit
            return view
        }()
        self.view.addSubview(self.previewImageView)
        let button: UIButton = {
            let button = UIButton(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
            button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
            button.setTitle("拍照", for: .normal)
            return button
        }()
        self.view.addSubview(button)
        camera?.commitConfiguration()
    }
    
}

extension TLCameraViewController: TLCameraDelegate {
    public func camera(_ camera: TLCamera, didReceiveSampleImage ciImage: CIImage) {
        let context = CIContext()
        let imageRef = context.createCGImage(ciImage, from: ciImage.extent)!
        
        let uiImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: .up)
        DispatchQueue.main.async {
            self.previewImageView.image = uiImage
        }
    }
}

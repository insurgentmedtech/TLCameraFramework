//
//  ViewController.swift
//  Sample App
//
//  Created by 刘腾 on 2019-08-19.
//  Copyright © 2019 Teng Liu. All rights reserved.
//

import UIKit
import TLCameraFramework

class ViewController: UIViewController {
    
    var camera: TLCamera?
    @IBOutlet var previewImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // set up camera
        camera = TLCamera()
        camera?.delegate = self
    }
    
    @IBAction func capturePhoto(_ sender: UIButton) {
        self.camera?.interfaceOrientation = UIApplication.shared.statusBarOrientation
        self.camera?.capturePhoto()
    }
    
    @IBAction func rotateCamera(_ sender: UIButton) {
        sender.isEnabled = false
        self.camera?.switchToCamera(.front, completion: { (success, error) in
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.camera?.commitConfiguration()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.camera?.stopCaptureSession()
        }
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.camera?.interfaceOrientation = UIApplication.shared.statusBarOrientation
        }
        switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft: print("landscapeLeft")
            case .landscapeRight: print("landscapeRight")
            case .portrait: print("portrait")
            case .portraitUpsideDown: print("portraitUpsideDown")
        case .unknown:
            print("Unknown.")
        @unknown default:
            print("default")
        }
    }

}


extension ViewController: TLCameraDelegate {
    public func camera(_ camera: TLCamera, didReceiveSampleImage ciImage: CIImage) {
        let ciImage = ciImage.applyingFilter("CIPhotoEffectInstant")
        let context = CIContext()
        let imageRef = context.createCGImage(ciImage, from: ciImage.extent)!
        
        let imageOrientation: UIImage.Orientation = {
            if let interfaceOrientation = self.camera?.interfaceOrientation {
                switch interfaceOrientation {
                case .portrait: return .right
                case .landscapeLeft: return .down
                case .landscapeRight: return .up
                case .portraitUpsideDown: return .left
                default:
                    return .right
                }
            } else {
                return .right
            }
        }()
        let uiImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: imageOrientation)
        
        DispatchQueue.main.async {
            self.previewImageView.image = uiImage
        }
    }
    
    public func camera(_ camera: TLCamera, didCaptureImage ciImage: CIImage) {
        print(ciImage)
    }
}

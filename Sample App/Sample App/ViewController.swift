//
//  ViewController.swift
//  Sample App
//
//  Created by 刘腾 on 2019-08-19.
//  Copyright © 2019 Teng Liu. All rights reserved.
//

import UIKit
import TLCameraFramework
import Photos

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
        sender.isEnabled = false
        self.camera?.interfaceOrientation = UIApplication.shared.statusBarOrientation
        self.camera?.capturePhoto() { error in
            if let e = error {
                print(e.localizedDescription)
            }
            DispatchQueue.main.async { sender.isEnabled = true }
        }
    }
    
    @IBAction func rotateCamera(_ sender: UIButton) {
        guard let camera = camera else {return}
        sender.isEnabled = false
        let newPosition: TLCamera.Position = {
            switch camera.currentDevicePosition {
            case .rearDualLens: return .front
            case .front: return .rearDualLens
            default: return .rearDualLens
            }
        }()
        camera.switchToCamera(newPosition, completion: { (success, error) in
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        camera?.configure() { (success, error) in
            print(error?.localizedDescription ?? "Configured with no error.")
            return
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
                if camera.currentDevicePosition == .rearDualLens {
                    switch interfaceOrientation {
                    case .portrait: return .right
                    case .landscapeLeft: return .down
                    case .landscapeRight: return .up
                    case .portraitUpsideDown: return .left
                    default:
                        return .right
                    }
                } else {
                    switch interfaceOrientation {
                    case .portrait: return .leftMirrored
                    case .landscapeLeft: return .downMirrored
                    case .landscapeRight: return .upMirrored
                    case .portraitUpsideDown: return .rightMirrored
                    default:
                        return .right
                    }
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
        var image = ciImage
        image = image.oriented(.up)
//        image = image.applyingFilter("CIColorEffectInstant")
//        print(ciImage.extent)
        if let data = CIContext().heifRepresentation(of: image, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, options: [:]) {
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: PHAssetResourceType.photo, data: data, options: nil)
            }, completionHandler: { (success, error) in
                guard success else {
                    print("Error saving to Camera Roll:", error?.localizedDescription ?? "Unknown error.")
                    return
                }
                print("Saved.")
            })
        }
        
    }
}

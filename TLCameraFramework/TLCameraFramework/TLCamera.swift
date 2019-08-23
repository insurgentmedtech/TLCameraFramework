//
//  TLCamera.swift
//  TLCameraFramework
//
//  Created by 刘腾 on 2019-08-20.
//  Copyright © 2019 Teng Liu. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation

public final class TLCamera: NSObject {
    
    public weak var delegate: TLCameraDelegate?
    public var interfaceOrientation: UIInterfaceOrientation = .portrait
    public var currentDevicePosition: Position = .back
    
    var session: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        return session
    }()
    var discoverySession: AVCaptureDevice.DiscoverySession? {
        return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                mediaType: AVMediaType.video,
                                                position: .unspecified)
    }
    var photoOutput = AVCapturePhotoOutput()
    lazy var videoOutput: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "TLCameraBufferDelegate"))
        return output
    }()
    
    // MARK: Calculated variables
    var hasFlash: Bool { get {
        // FIXME: Needs implementation
        return false
    }}
    
    func device(ofPosition position: Position) -> AVCaptureDevice? {
        let devicePosition: AVCaptureDevice.Position = {
            switch position {
            case .back: return .back
            case .front: return .front
            default: return .back
            }
        }()
        guard let discoverySession = self.discoverySession else {return nil}
        for device in discoverySession.devices {
            if device.position == devicePosition {
                return device
            }
        }
        return nil
    }
    
    // MARK: Camera functions
    
    public func commitConfiguration() {
        do {
            guard let device = self.device(ofPosition: currentDevicePosition) else {return}
            let input = try AVCaptureDeviceInput(device: device)
            
            if self.session.canAddInput(input) &&
                self.session.canAddOutput(self.photoOutput) &&
                self.session.canAddOutput(self.videoOutput) {
                self.photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.hevc])], completionHandler: nil)
                self.session.addInput(input)
                self.session.addOutput(self.photoOutput)
                self.session.addOutput(videoOutput)
                self.session.commitConfiguration()
                self.session.startRunning()
                print("Capture session is now running.")
            }
        } catch {
            print("Error linking device to AVInput.")
            return
        }
    }
    
    public func stopCaptureSession() {
        self.session.stopRunning()
    }
    
    /// Captures image with the current set up.
    public func capturePhoto() {
//        guard let device = self.session.inputs. else {
//            print("Can't find the current camera.")
//            return
//        }
        guard self.session.isRunning else {
            print("Capture session is not running.")
            return
        }
        let captureSettings: AVCapturePhotoSettings = {
            let settings = AVCapturePhotoSettings()
//            if device.hasFlash {
//                settings.flashMode = .off
//            }
            return settings
        }()
        self.photoOutput.capturePhoto(with: captureSettings, delegate: self)
    }
    
    public func switchToCamera(_ position: Position, completion: @escaping (Bool, Error?) -> Void) {
        guard session.isRunning else {
            // Session is not running.
            completion(false, nil)
            return
        }
        session.stopRunning()
        session.inputs.forEach { (input) in
            session.removeInput(input)
        }
        if let device = device(ofPosition: position),
            let input = try? AVCaptureDeviceInput(device: device) {
            session.addInput(input)
            session.startRunning()
            completion(true, nil)
        } else {
            completion(false, nil)
        }
    }
    
    public func setFlash(to flashMode:FlashMode, completion: @escaping (Bool, Error?) -> Void) {
        completion(true, nil)
    }
}

// MARK: - Enums
extension TLCamera {
    public enum Position {
        case front
        case back
    }
    public enum FlashMode {
        case off
        case on
        case auto
    }
}

extension TLCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
}

// MARK: - AVFoundation Delegates
extension TLCamera: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            fatalError(error!.localizedDescription)
        }
        if let data = photo.fileDataRepresentation(),
            let ciImage = CIImage(data: data) {
            delegate?.camera?(self, didCaptureImage: ciImage)
        }
    }
    
    // This is the block that handles frame-to-frame viewfinding.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
//        var orientation: CGImagePropertyOrientation!
//        switch (self.viewController.viewOrientation) {
//        case .landscapeRight:
//            if self.currentCamera == Camera.front {orientation = .downMirrored} else {orientation = .up}
//        case .landscapeLeft:
//            if self.currentCamera == Camera.front {orientation = .upMirrored} else {orientation = .down}
//        default:
//            orientation = .down
//        }
        delegate?.camera?(self, didReceiveSampleImage: ciImage)
    }
}

@objc public protocol TLCameraDelegate {
    @objc optional func camera(_ camera: TLCamera, didReceiveSampleImage ciImage: CIImage)
    @objc optional func camera(_ camera: TLCamera, didCaptureImage ciImage: CIImage)
}

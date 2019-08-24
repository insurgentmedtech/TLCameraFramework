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

public enum TLCameraError: Error {
    case sessionIsMissing
    case sessionIsNotRunning
    case sessionIsBusyCapturing
    case inputDeviceLinkageError
    case inputDeviceNotFound
    case cameraAccessDenied
    case cameraAccessNotDetermined
    case inputDeviceDoesNotHaveFlash
    case unknownError
}

// MARK: - Enums
extension TLCamera {
    /// The describer of a camera for the device.
    public enum Position {
        /// The camera in the front of the device, usually having the same facing as the screen.
        case front
        /// The wide angle camera on the back of a device, if available.
        case rearWideAngle
        /// The telephoto camera on the back of a device, if available.
        case rearTelephoto
        /// The dual lens camera matrix on the back of the device if available; on devices with one camera on the back, this is the same as `rearWideAngle`.
        case rearDualLens
    }
    public enum FlashMode {
        case off
        case on
        case auto
    }
    public enum AuthorizationStatus {
        case authorized
        case denied
        case notDetermined
        case restricted
        case unknown
    }
}

public final class TLCamera: NSObject {
    
    private var _currentDevicePosition: Position = .rearDualLens
    private var _availableDevices: [Position: AVCaptureDevice] = [:]
    private var _isSessionCapturing = false
    private var _captureCompletionBlock: ((Error?) -> Void)? = nil
    var session: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        return session
    }()
    var photoOutput = AVCapturePhotoOutput()
    lazy var videoOutput: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "TLCameraBufferDelegate"))
        return output
    }()
    
    /// The delegate that handles image processing for previews and captured photos and videos.
    public weak var delegate: TLCameraDelegate?
    
    public var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    /// The read-only device position property. To change the device to another one, use `switchDevice(to: Position)`.
    public var currentDevicePosition: Position {
        return _currentDevicePosition
    }
    
    /// Returns a `Bool` indecating whether there is flash enabled for the current device. This may include normal camera flashes, and
    /// screen-enabled flashes seen on iPhone 6s and later. If a current device is not found, this will also return `false`.
    public var currentDeviceHasFlash: Bool {
        return device(of: _currentDevicePosition)?.hasFlash ?? false
    }
    
    func device(of position: Position) -> AVCaptureDevice? {
        let devicePosition: AVCaptureDevice.Position = {
            switch position {
            case .rearTelephoto, .rearWideAngle, .rearDualLens: return .back
            case .front: return .front
            }
        }()
        let deviceType: AVCaptureDevice.DeviceType = {
            switch position {
            case .rearDualLens: return .builtInDualCamera
            case .front, .rearWideAngle: return .builtInWideAngleCamera
            case .rearTelephoto: return .builtInTelephotoCamera
            }
        }()
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [deviceType],
                                                                mediaType: AVMediaType.video,
                                                                position: devicePosition)
        return discoverySession.devices.first
    }
    
    // MARK: Camera functions
    
    /// Configurate the object for camera use. Should only be called once per lifetime, unless camera access wasn't granted in previous calls.
    public func configure(_ completion: @escaping ((Bool, Error?) -> Void)) {
        guard TLCamera.authorizationStatus == .authorized else {
            if TLCamera.authorizationStatus == .notDetermined {
                completion(false, TLCameraError.cameraAccessNotDetermined)
            } else {
                completion(false, TLCameraError.cameraAccessDenied)
            }
            return
        }
        do {
            guard let device = self.device(of: currentDevicePosition) else {
                completion(false, TLCameraError.inputDeviceNotFound)
                return
            }
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
                completion(true, nil)
            } else {
                completion(false, TLCameraError.inputDeviceLinkageError)
            }
        } catch {
            completion(false, error)
            return
        }
    }
    
    public func stopCaptureSession() {
        self.session.stopRunning()
    }
    
    public func startCaptureSession() {
        self.session.startRunning()
    }
    
    /// Captures image with the current set up.
    public func capturePhoto(_ completion: @escaping ((Error?) -> Void)) {
        guard self.session.isRunning else {
            print("Capture session is not running.")
            return
        }
        let captureSettings: AVCapturePhotoSettings = {
            let settings = AVCapturePhotoSettings()
            //settings.livePhotoMovieFileURL =
//            if device.hasFlash {
//                settings.flashMode = .off
//            }
            return settings
        }()
        self._captureCompletionBlock = completion
        
        self.photoOutput.capturePhoto(with: captureSettings, delegate: self)
    }
    
    public func switchToCamera(_ position: Position, completion: @escaping (Bool, Error?) -> Void) {
        guard session.isRunning else { completion(false, TLCameraError.sessionIsNotRunning); return }
        guard _isSessionCapturing == false else { completion(false, TLCameraError.sessionIsBusyCapturing); return }
        session.stopRunning()
        session.inputs.forEach { (input) in
            session.removeInput(input)
        }
        self._currentDevicePosition = position
        if let device = device(of: self._currentDevicePosition),
            let input = try? AVCaptureDeviceInput(device: device) {
            session.addInput(input)
            session.startRunning()
            completion(true, nil)
        } else {
            completion(false, TLCameraError.inputDeviceNotFound)
        }
    }
    
    public func setFlash(to flashMode:FlashMode, completion: @escaping (Bool, Error?) -> Void) {
        completion(true, nil)
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
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        delegate?.camera?(self, didReceiveSampleImage: ciImage)
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        self._isSessionCapturing = false
        self._captureCompletionBlock?(error)
    }
}

@objc public protocol TLCameraDelegate {
    @objc optional func camera(_ camera: TLCamera, didReceiveSampleImage ciImage: CIImage)
    @objc optional func camera(_ camera: TLCamera, didCaptureImage ciImage: CIImage)
}

extension TLCamera {
    static var authorizationStatus: TLCamera.AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        default: return .unknown
        }
    }
    
    static func requestAccess(_ completion: @escaping (Bool) -> Void) {
        switch TLCamera.authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                completion(granted)
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
        }
    }
}

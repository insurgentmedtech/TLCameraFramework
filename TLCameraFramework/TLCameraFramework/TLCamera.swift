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
    case illegalConfiguration
    case unknownError
}

// MARK: - Enums
extension TLCamera {
    /// The describer of a camera for the device.
    public enum Position {
        /// The default device on the back, the first available in the list:
        /// - `builtInTripleCamera`
        /// - `builtInDualWideCamera`
        /// - `builtInDualCamera`
        /// - `builtInWideAngleCamera`
        case rearDefault
        /// The default device on the front if available
        case frontDefault
//        /// The camera in the front of the device, usually having the same facing as the screen.
//        case front
//        /// The wide angle camera on the back of a device, if available.
//        case rearWideAngle
//        /// The ultra wide camera on the back of a device, if available.
//        case rearUltraWideAngle
//        /// The telephoto camera on the back of a device, if available; otherwise this is the same as `rearWideAngle`
//        case rearTelephoto
//        /// The dual lens camera matrix of a wide and a telephoto camera on the back of the device if available; otherwise, this is the same as `rearWideAngle`.
//        case rearUltraWideDualLens
//        /// The dual lens camera matrix of an ultra wide and a wide camera, if available. Otherwise, this is the same as `rearWideAngle`.
//        case rearTelephotoDualLens
//        /// The Triple lens camera matrix on the back of the iPhone 11 Pro; on devices without such camera matrix, this is the same as `rearDualLens`.
//        case rearTripleLens
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
    
    private var _currentDevicePosition: Position = .rearDefault
    private var _availableDevices: [Position: AVCaptureDevice] = [:]
    private var _isSessionCapturing = false
    private var _captureCompletionBlock: ((Error?) -> Void)? = nil
    private var _flashMode = FlashMode.off
    
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
    public var currentFlashMode: FlashMode {
        return _flashMode
    }
    public var currentZoomFactor: CGFloat? {
        return device(of: _currentDevicePosition)?.videoZoomFactor
    }
    
    /// Returns a `Bool` indecating whether there is flash enabled for the current device. This may include normal camera flashes, and
    /// screen-enabled flashes seen on iPhone 6s and later. If a current device is not found, this will also return `false`.
    public var currentDeviceHasFlash: Bool {
        return device(of: _currentDevicePosition)?.hasFlash ?? false
    }
    
    public func currentDeviceMinZoomFactor() -> CGFloat? {
        guard let device = device(of: _currentDevicePosition) else {return nil}
        return device.minAvailableVideoZoomFactor
    }
    
    public func currentDeviceMaxZoomFactor() -> CGFloat? {
        guard let device = device(of: _currentDevicePosition) else {return nil}
        return device.maxAvailableVideoZoomFactor
    }
    
    func device(of position: Position) -> AVCaptureDevice? {
        switch position {
        case .rearDefault:
            if #available(iOS 13.0, *) {
                if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
                    return device
                }
                if let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                    return device
                }
            }
            if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                return device
            }
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                return device
            }
            return nil
        case .frontDefault:
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                return device
            }
            return nil
        }
    }
    
    // MARK: Camera functions
    
    /// Configurate the object for camera use. Should only be called once per lifetime, unless camera access wasn't granted in previous calls.
    public func configure(_ completion: @escaping ((Bool, Error?) -> Void) = {_, _ in return}) {
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
                throw TLCameraError.inputDeviceLinkageError
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
    
    /// Captures image with the current set up. The completion handler is called when capture ends with success or with an error.
    /// To work with the image being captured, refer to the delegate methods of `TLCameraDelegate`.
    public func capturePhoto(_ completion: @escaping ((Error?) -> Void)) {
        guard self.session.isRunning else {
            completion(TLCameraError.sessionIsBusyCapturing)
            return
        }
        guard let device = device(of: _currentDevicePosition) else {
            completion(TLCameraError.inputDeviceNotFound)
            return
        }
        let captureSettings: AVCapturePhotoSettings = {
            let settings = AVCapturePhotoSettings()
            switch self._flashMode {
            case .on:
                if device.hasFlash { settings.flashMode = .on }
            case .off:
                settings.flashMode = .off
            case .auto:
                if device.hasFlash { settings.flashMode = .auto }
            }
            return settings
        }()
        self._captureCompletionBlock = completion
        
        self.photoOutput.capturePhoto(with: captureSettings, delegate: self)
    }
    
    public func switchToCamera(_ position: Position, duration: CMTime? = nil, iso: Float? = nil, completion: @escaping (Bool, Error?) -> Void = {_, _ in return}) {
        guard session.isRunning else { completion(false, TLCameraError.sessionIsNotRunning); return }
        guard _isSessionCapturing == false else { completion(false, TLCameraError.sessionIsBusyCapturing); return }
        session.stopRunning()
        session.inputs.forEach { (input) in
            session.removeInput(input)
        }
        self._currentDevicePosition = position
        guard let device = device(of: self._currentDevicePosition) else {
            completion(false, TLCameraError.inputDeviceNotFound)
            return
        }
        do {
            let isConfiguringExposure = (duration != nil || iso != nil ) && device.isExposureModeSupported(.custom)
            if isConfiguringExposure {
                try device.lockForConfiguration()
                device.exposureMode = .custom
                device.setExposureModeCustom(duration: duration ?? AVCaptureDevice.currentExposureDuration,
                                             iso: iso ?? AVCaptureDevice.currentISO,
                                             completionHandler: nil)
                device.unlockForConfiguration()
            }
            if let input = try? AVCaptureDeviceInput(device: device) {
                session.addInput(input)
                session.startRunning()
                completion(true, nil)
            } else {
                throw TLCameraError.inputDeviceLinkageError
            }
        } catch {
            completion(false, error)
        }
    }
    
    public func setCaptureParameters(focusPointOfInterest: CGPoint? = nil, exposurePointOfInterest: CGPoint? = nil, exposureBias: Float? = nil) {
        guard let device = device(of: _currentDevicePosition) else {return}
        do {
            try device.lockForConfiguration()
            if let point = focusPointOfInterest,
                CGRect(origin: .zero, size: CGSize(width: 1, height: 1)).contains(point) {
                device.focusPointOfInterest = point
            }
            if let point = exposurePointOfInterest,
                CGRect(origin: .zero, size: CGSize(width: 1, height: 1)).contains(point) {
                device.exposurePointOfInterest = point
            }
            if let ev = exposureBias,
                ev <= device.maxExposureTargetBias,
                ev >= device.minExposureTargetBias {
                device.setExposureTargetBias(ev, completionHandler: nil)
            }
            device.unlockForConfiguration()
        } catch {
            return
        }
    }
    
    public func setFlash(to flashMode:FlashMode, completion: @escaping (Bool, Error?) -> Void = {_, _ in return}) {
        self._flashMode = flashMode
        completion(true, nil)
    }
    
    public func setZoomFactor(to factor: CGFloat, completion: @escaping (Bool, Error?) -> Void = {_, _ in return}) {
        guard let device = device(of: _currentDevicePosition) else {
            completion(false, TLCameraError.inputDeviceNotFound)
            return
        }
        guard factor >= device.minAvailableVideoZoomFactor, factor <= device.maxAvailableVideoZoomFactor else {
            completion(false, TLCameraError.illegalConfiguration)
            return
        }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = factor
            device.unlockForConfiguration()
        } catch {
            completion(false, error)
        }
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
    public static var authorizationStatus: TLCamera.AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        default: return .unknown
        }
    }
    
    public static func requestAccess(_ completion: @escaping (Bool) -> Void) {
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

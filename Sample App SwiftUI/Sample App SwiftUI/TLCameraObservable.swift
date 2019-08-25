//
//  TLCameraObservable.swift
//  Sample App SwiftUI
//
//  Created by 刘腾 on 2019-08-24.
//  Copyright © 2019 Teng Liu. All rights reserved.
//

import TLCameraFramework
import SwiftUI

class CameraCoordinator: ObservableObject {
    @Published var image: UIImage = UIImage()
    let camera = TLCamera()
}

extension CameraCoordinator: TLCameraDelegate {
    func camera(_ camera: TLCamera, didReceiveSampleImage ciImage: CIImage) {
        if let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) {
            DispatchQueue.main.async {
                self.image = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
            }
        }
    }
}



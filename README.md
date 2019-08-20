# Overview
`TLCameraFramework` is a handy iOS library that provides easy access and customization to the camera.

```swift
class TLCamera {
	
	enum Position {
		case front
		case back
	}
	
	enum FlashMode {
		case off
		case on
		case auto
	}
	
	weak var controller: TLCameraViewController?
	weak var delegate: TLCameraDelegate?
	
	init (withController controller: TLCameraViewController) {
		super.init()
		self.controller = controller
	}
	
	var hasFlash: Bool { get }
	var currentCameraPosition: Position { get }
}

extension TLCamera: AVDeviceOutputDelegate {
	func dataOutput() {
		
	}
	
}

protocol TLCameraDelegate {
	func camera(_ camera: TLCamera, didReceivePreviewImage previewImage: CIImage) 
	func camera(_ camera: TLCamera, didCaptureImage capturedImage: CIImage)
}

class TLCameraViewController : UIViewController {
	var previewImageView: UIImageView
	var camera: TLCamera {
		return TLCamera(withController: self)
	}
}
```

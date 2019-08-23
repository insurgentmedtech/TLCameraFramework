# Overview
`TLCameraFramework` is a handy iOS library that provides easy access and customization to the camera.

## Quick Start

1. `import` the framework:

	```swift
	import TLCameraFramework
	```

2. Create a `TLCamera` object as a property of the view controller, and set the delegate to the same view controller. Make sure the view controller conforms to the `TLCameraDelegate` protocol.

	```swift
	class ViewController: UIViewController {
		lazy var camera = TLCamera()
		override func viewDidLoad() {
			super.viewDidLoad()
			camera.delegate = self
		}
	}
	
	extension ViewController: TLCameraDelegate {
		
	}
	```

3. Implement the protocol function to update the preview to the view's layer. Also make the view's layer to aspect fill.

	```swift
	class ViewController: UIViewController {
		override func viewDidLoad() {
			// ...
			self.view.layer.contentsGravity = .resizeAspectFill
		}
	}
	
	extension ViewController: TLCameraDelegate {
		func camera(camera, didReceivePreview: ciImage) {
			let ciImage = ciImage.imageByApplyingOrientation(.right) // Assuming the device is in portrait mode; change accordingly.
			
			DispatchQueue.main.async {
				self.view.layer.contents = CIContext().createCGImage(ciImage, from: ciImage.extent)
			}
		}
	}
	```

4. Implement the protocol function to handle image captured.

	```swift
	extension ViewController: TLCameraDelegate {
		//...
		func camera(camera, didCaptureImage: ciImage) {
			print(ciImage)
			// Handle image processing and data persistence (to Core Data model, to user's Album, etc.)
		}
	}
	```

5. Add Camera flow control.

	```swift
	class ViewController: UIViewController {
		//...
		@IBAction func didClickSwitchCamera(_ sender: UIButton) {
			sender.isEnabled = false
			camera.switchCameraTo(.front) { (success, error) in
				DispatchQueue.main.async {
					sender.isEnabled = true
				}
				if success {
					print("Switched camera!")
				} else {
					print("Error switching camera: \(error?.localizedDescription ?? "Unknown Error")")
				}
			}
		}
		
		@IBAction func didClickShutter(_ sender: UIButton) {
			
		}
		//...
	}
	```

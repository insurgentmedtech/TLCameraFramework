# Overview
`TLCameraFramework` is a handy iOS library that provides easy access and customization to the camera.

Advantages:

- It uses capture device with `TLCamera`.`Position` to be either `rearDefault` or `frontDefault`. The framework is designed to offer convenience when you just need to take a photo, not for when you want granular controls with multiple input sources.
- Abstract `currentEffectiveZoomFactor` conveys the video zoom factor that matters to a user. With any camera, 0.5x is 13mm equivalent; 1x is 26-28mm equivalend, and 2x is 52mm equivalent.
- Do-Catch for common errors such as locking cameras for configuration, and confiuring them with unreasonable settings.
- Completion handlers abound, so that you can finish UI flow control within the enclosure.


## Quick Start

```swift
import TLCameraFramework // 1. Import the framework
import UIKit

class ViewController: UIViewController {
	
	lazy var camera = TLCamera() // 2. Store the `TLCamera` property
	
	override func viewDidLoad() {
		super.viewDidLoad()
		camera.delegate = self // 3. Assign the `TLCamera` delegate to the view controller
		view.layer.contentsGravity = .resizeAspectFill // 4. Prepare the layer to display camera preview properly
	}
	
	@IBAction func didClickSwitchCamera(_ sender: UIButton) {
		// 5. Implement user interaction with Switch Camera button
		sender.isEnabled = false
		camera?.switchCameraTo(.front) { (success, error) in
			// 5.1. Call the method, and implement completion handler
			DispatchQueue.main.async {
				// 5.2. Re-enable the button whether success or not
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
		// 6. Implement user interaction with Shutter button
		camera?.captureImage() // 6.1. Success or not, completion and image will be sent to the delegate
	}
}
	
extension ViewController: TLCameraDelegate {
	func camera(camera, didReceivePreview: ciImage) {
		// 7.1. Handle preview image display
		let ciImage = ciImage.imageByApplyingOrientation(.right) // 7.2. Assuming the device is in portrait mode; change accordingly.
		
		DispatchQueue.main.async {
			// 7.3. Display the image on the layer on the main thread
			self.view.layer.contents = CIContext().createCGImage(ciImage, from: ciImage.extent)
		}
	}
	
	func camera(camera, didCaptureImage: ciImage) {
		print(ciImage)
		// 6.2. Handle image processing and data persistence (to Core Data model, to user's Album, etc.)
	}
}
```

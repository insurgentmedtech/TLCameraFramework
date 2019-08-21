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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let camera = TLCameraViewController.init()
        present(camera, animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

}


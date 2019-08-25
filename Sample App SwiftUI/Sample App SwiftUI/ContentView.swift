//
//  ContentView.swift
//  Sample App SwiftUI
//
//  Created by 刘腾 on 2019-08-20.
//  Copyright © 2019 Teng Liu. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: CameraCoordinator
    var body: some View {
        Image(uiImage: coordinator.image)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

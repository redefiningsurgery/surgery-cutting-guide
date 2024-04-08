//
//  SurgeryView.swift
//  RedefineGuide
//
//  Created by Stephen Potter on 4/8/24.
//

import SwiftUI

/// The live view of surgery.
struct SurgeryView: View {
    @ObservedObject var model: SurgeryModel

    var body: some View {
        VStack {
            ARViewContainer(model: model)
            Button("Add Something") {
                model.addSomething()
            }
        }
    }
}

#Preview {
    return SurgeryView(model: SurgeryModel())
}

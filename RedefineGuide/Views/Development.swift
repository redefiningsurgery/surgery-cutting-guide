//
//  Development.swift
//  RedefineGuide
//
//  Created by Stephen Potter on 5/21/24.
//
// THIS IS A SILLY WAY FOR STEVE TO HACK ON THINGS WITHOUT DISRUPTING THE APP.  Please delete this later

import SwiftUI

struct Development: View {
    @ObservedObject var model: SurgeryModel

    var body: some View {
        VStack {
            ARViewContainer(model: model)
        }.task {
            model.startSession()
        }
    }
}

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
                .overlay(alignment: .top) {
                    HStack {
                        VStack {
                            Stepper(value: $model.axis1X, in: -10...10, step: 0.001) {
                                Text("X1: \(model.axis1X, specifier: "%.3f")")
                            }
                            Stepper(value: $model.axis1Y, in: -10...10, step: 0.001) {
                                Text("Y1: \(model.axis1Y, specifier: "%.3f")")
                            }
                            Stepper(value: $model.axis1Z, in: -10...10, step: 0.001) {
                                Text("Z1: \(model.axis1Z, specifier: "%.3f")")
                            }
                        }
                        VStack {
                            Stepper(value: $model.axis2X, in: -10...10, step: 0.001) {
                                Text("X2: \(model.axis2X, specifier: "%.3f")")
                            }
                            Stepper(value: $model.axis2Y, in: -10...10, step: 0.001) {
                                Text("Y2: \(model.axis2Y, specifier: "%.3f")")
                            }
                            Stepper(value: $model.axis2Z, in: -10...10, step: 0.001) {
                                Text("Z2: \(model.axis2Z, specifier: "%.3f")")
                            }
                        }
                    }
                }

        }.task {
            model.startSession()
        }
    }
}

//
//  SettingsForm.swift
//  RedefineGuide
//
//  Created by Stephen Potter on 6/13/24.
//

import SwiftUI

struct SettingsForm: View {
    @ObservedObject var settings: Settings = Settings.shared

    var body: some View {
        Form {
            Section(header: Text("Server URL")) {
                TextField("Server URL", text: $settings.devServerUrl)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            Section(header: Text("Dev Settings")) {
                Toggle("Continuously track using server", isOn: $settings.continuouslyTrack)
                Toggle("Save server requests", isOn: $settings.saveRequests)
                Toggle("Show AR debugging visuals", isOn: $settings.showARDebugging)
                Toggle("Align to camera", isOn: $settings.alignOverlayWithCamera)
                Toggle("Show hole axes", isOn: $settings.enableAxes)
            }
        }
    }
}

#Preview {
    SettingsForm()
}

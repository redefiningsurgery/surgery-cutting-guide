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
            Section(header: Text("Dev Settings")) {
                TextField("Server URL", text: $settings.devServerUrl)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Toggle("Continuously track using server", isOn: $settings.continuouslyTrack)
                Toggle("Save server requests", isOn: $settings.saveRequests)
            }
        }
    }
}

#Preview {
    SettingsForm()
}

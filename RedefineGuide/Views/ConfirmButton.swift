//
//  ConfirmButton.swift
//  RedefineGuide
//
//  Created by Stephen Potter on 5/30/24.
//

import SwiftUI

struct ConfirmButton<Label> : View where Label : View {
    let action: () -> Void
    let label: () -> Label
    var alertTitle: String = "Confirm"
    var alertMessage: String = "Are you sure you want to do this?"
    var alertConfirmButton: String = "OK"
    var alertCancelButton: String = "Cancel"

    @State private var showingAlert = false
    
    // General initializer
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    // Convenience initializer for using a String directly
    init(_ title: String, action: @escaping () -> Void) where Label == Text {
        self.action = action
        self.label = { Text(title) }
    }
    
    var body: some View {
        Button(action: {
            self.showingAlert = true
        }) {
            label()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .destructive(Text(alertConfirmButton), action: action),
                secondaryButton: .cancel(Text(alertCancelButton))
            )
        }
    }
}

// Extension to add modifiers for alertTitle and alertMessage
extension ConfirmButton {
    func alertTitle(_ title: String) -> ConfirmButton {
        var button = self
        button.alertTitle = title
        return button
    }
    
    func alertMessage(_ message: String) -> ConfirmButton {
        var button = self
        button.alertMessage = message
        return button
    }

    func alertConfirmButton(_ text: String) -> ConfirmButton {
        var button = self
        button.alertConfirmButton = text
        return button
    }

    func alertCancelButton(_ text: String) -> ConfirmButton {
        var button = self
        button.alertCancelButton = text
        return button
    }
}

#Preview("Default") {
    ConfirmButton("Tap Me") {
        print("Action confirmed!")
    }
}

#Preview("Custom alert stuff") {
    ConfirmButton(action: {
        print("Action confirmed!")
    }) {
        Text("Tap me")
    }
    .alertTitle("Confirmation Needed")
    .alertMessage("Do you really want to proceed?")
    .alertConfirmButton("YUP")
    .alertCancelButton("Nevermind")
}

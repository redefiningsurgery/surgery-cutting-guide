import SwiftUI

/// Same as Button, except it executes an async function when pressed.  While the task is running, the button cannot be pressed again.  And a progress view will show after some delay
/// Shout out to https://www.swiftbysundell.com/articles/building-an-async-swiftui-button/ for the help
struct AsyncButton<Label: View>: View {
    /// After this many milliseconds, the button will change visually (possibly with a progress spinner) to give feedback to the user that the operation is in progress
    /// Set to 0 to show the loading state immediately, and -1 to disable the feature
    var loadingDelayMs: Int32 = 200
    
    /// When set, a progress spinner will be shown if the task takes longer than loadingDelayMs
    var showProgressViewDuringLoading = false

    /// If the task takes longer than loadingDelayMs, the button label's opacity will change to this value
    var opacityDuringLoading = 0.5

    /// The action is run in a task.  This is the priority of that task.  Note this will be inherited by child tasks.
    var taskPriority: TaskPriority = .userInitiated

    var showSuccessIndicator: Bool = false
    
    var successSystemImageName: String = "checkmark.circle.fill"

    var successIndicatorSeconds = 2.0
    
    var action: () async -> Void
    @ViewBuilder var label: () -> Label
    
    @State private var isRunning = false
    /// Becomes true when enough time has passed since the task started that the button should be disabled for visual feedback to the user
    @State private var delayOccurred = false
    /// Indicates whether a success completion animation should be shown
    @State private var showSuccess = false
    /// Number of times the button has been pressed
    @State private var count = 0
    
    var body: some View {
        Button(
            action: {
                guard !isRunning else {
                    return
                }
                count += 1

                // Button was pressed quickly after it succeeded.  Immediately hide the indicator
                if showSuccess {
                    showSuccess = false
                }
                isRunning = true
            
                Task(priority: taskPriority) {
                    var delayTask: Task<Void, Error>? = nil
                    if loadingDelayMs > 0 {
                        delayTask = Task {
                            try await Task.sleep(nanoseconds: nanosecondsPerMillisecond * UInt64(loadingDelayMs))
                            delayOccurred = true
                        }
                    } else if loadingDelayMs == 0 {
                        delayOccurred = true
                    }
                    
                    await action()
                    delayTask?.cancel()

                    withAnimation {
                        showSuccess = true
                    }
                    delayOccurred = false
                    
                    // Reset success state after animation completes
                    Task.detached {
                        let currCount = count
                        try await Task.sleep(nanoseconds: getNanoseconds(seconds: successIndicatorSeconds))
                        withAnimation {
                            // if it was pressed during this task, then don't do anything
                            if currCount == self.count {
                                showSuccess = false
                            }
                        }
                    }
                    
                    isRunning = false
                }
            },
            label: {
                ZStack {
                    if showProgressViewDuringLoading {
                        label().opacity(delayOccurred ? opacityDuringLoading : 1)
                        if delayOccurred {
                            ProgressView()
                                .background(Color.clear) // You can set a background color to make it more visible during debugging
                        }
                    } else {
                        label().opacity(delayOccurred ? opacityDuringLoading : 1)
                    }
                    if showSuccess {
                        Image(systemName: successSystemImageName)
                            .scaledToFit()
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        )
    }
}


#Preview("no spinner") {
    // it'll just disable after a few seconds
    AsyncButton(loadingDelayMs: 500, action: {
        try? await Task.sleep(nanoseconds: nanosecondsPerSecond)
   }, label: {
       Image(systemName: "hand.thumbsup.fill")
   })
}

#Preview("spinner") {
    AsyncButton(showProgressViewDuringLoading: true, opacityDuringLoading: 0, action: {
        try? await Task.sleep(nanoseconds: nanosecondsPerSecond)
   }, label: {
       Text("Click me please")
   })
}

#Preview("spinner with success indicator") {
    HStack {
        AsyncButton(showProgressViewDuringLoading: true, opacityDuringLoading: 0, showSuccessIndicator: true, successIndicatorSeconds: 4, action: {
            try? await Task.sleep(nanoseconds: nanosecondsPerSecond)
        }, label: {
            Text("Click me please")
        })
    }.background(
        RoundedRectangle(cornerRadius: 4)
            .fill(.red)
    )
}

#Preview("immediate loading state") {
    AsyncButton(loadingDelayMs: 0, action: {
        try? await Task.sleep(nanoseconds: nanosecondsPerSecond)
   }, label: {
       Image(systemName: "hand.thumbsup.fill")
   })
}

#Preview("no loading state") {
    AsyncButton(loadingDelayMs: -1, action: {
        try? await Task.sleep(nanoseconds: nanosecondsPerSecond)
   }, label: {
       Image(systemName: "hand.thumbsup.fill")
   })
}

#Preview("normal button for comparison") {
    Button(action: {}, label: {
       Image(systemName: "hand.thumbsup.fill")
   })
}

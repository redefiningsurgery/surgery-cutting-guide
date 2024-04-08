import Foundation

@MainActor
class AppInitializationModel: NSObject, ObservableObject {
    enum Status {
        case initializing
        case initialized
        case failed(String)
    }
    
    @Published var status: Status = .initializing
}

import Foundation
import SwiftUI

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var isNetworkReachable: Bool = true

    private init() {}
}

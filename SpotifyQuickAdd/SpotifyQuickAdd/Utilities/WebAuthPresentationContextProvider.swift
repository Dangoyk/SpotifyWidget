import AuthenticationServices
import Foundation
import UIKit

final class WebAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let window = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return window
        }

        if let window = scenes.flatMap(\.windows).first {
            return window
        }

        return ASPresentationAnchor()
    }
}

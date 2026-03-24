import SwiftUI
import UIKit

struct OverlayTestViewWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: OverlayTestViewController())
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

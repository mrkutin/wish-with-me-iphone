import SwiftUI

/// Invisible view that finds its parent UIScrollView and reports scroll offset changes.
/// Place this inside a ScrollView to track content offset.
struct ScrollOffsetTracker: UIViewRepresentable {
    @Binding var isScrolled: Bool
    var threshold: CGFloat = 3

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        context.coordinator.threshold = threshold
        DispatchQueue.main.async {
            if let scrollView = Self.findScrollView(from: view) {
                context.coordinator.observe(scrollView)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isScrolled: $isScrolled)
    }

    private static func findScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let parent = current?.superview {
            if let scrollView = parent as? UIScrollView {
                return scrollView
            }
            current = parent
        }
        return nil
    }

    class Coordinator: NSObject {
        @Binding var isScrolled: Bool
        var threshold: CGFloat = 3
        private var observation: NSKeyValueObservation?

        init(isScrolled: Binding<Bool>) {
            _isScrolled = isScrolled
        }

        func observe(_ scrollView: UIScrollView) {
            observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, change in
                guard let self, let offset = change.newValue else { return }
                let shouldScroll = offset.y > self.threshold
                if shouldScroll != self.isScrolled {
                    DispatchQueue.main.async {
                        self.isScrolled = shouldScroll
                    }
                }
            }
        }

        deinit {
            observation?.invalidate()
        }
    }
}

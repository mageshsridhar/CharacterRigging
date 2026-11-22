import Observation
import QuartzCore
import RiveRuntime
import UIKit

/// Loads the Rive head and moves it toward a target every frame, resting once it arrives.
@MainActor @Observable
final class FaceRig {
    enum State { case loading, ready(Rive), failed(String) }

    private(set) var state: State = .loading

    @ObservationIgnored var target = FaceParameters.neutral { didSet { wake() } }
    /// 0 is black and white, 1 is color.
    @ObservationIgnored var colorTarget = 0.0 { didSet { wake() } }
    @ObservationIgnored private var color = 0.0
    @ObservationIgnored private var motion = FaceMotion()
    @ObservationIgnored private var instance: ViewModelInstance?
    @ObservationIgnored private var file: File?
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var isLoading = false

    func load() async {
        guard instance == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        state = .loading
        do {
            let file = try await File(source: .local("head", .main), worker: Worker())
            let artboard = try await file.createArtboard()
            let instance = try await file.createViewModelInstance(.viewModelDefault(from: .artboardDefault(artboard)))
            let machine = try await artboard.createStateMachine(binding: instance)
            let rive = try await Rive(file: file, artboard: artboard, stateMachine: machine)
            self.file = file
            self.instance = instance
            // Start in the right look instead of fading to it.
            color = colorTarget
            instance.setValue(of: NumberProperty(path: "color"), to: Float(color))
            state = .ready(rive)
            startLink()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Stills of a face in both looks, or none if they can't be drawn.
    func thumbnails(of parameters: FaceParameters) async -> Thumbnails {
        guard let file else { return Thumbnails() }
        return (try? await FacePicture(file: file).thumbnails(of: parameters)) ?? Thumbnails()
    }

    var isResting: Bool { link?.isPaused ?? true }

    private func wake() { link?.isPaused = false }

    private func startLink() {
        let link = CADisplayLink(target: LinkProxy(self), selector: #selector(LinkProxy.tick))
        link.preferredFrameRateRange = .init(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    fileprivate func step(by dt: Double) {
        guard let instance else { return }
        let moved = motion.step(toward: target, by: dt, reduceMotion: UIAccessibility.isReduceMotionEnabled)
        for p in moved {
            instance.setValue(of: NumberProperty(path: p.rawValue), to: Float(motion.values[p] ?? p.neutral))
        }
        let isFading = color != colorTarget
        if isFading {
            let change = dt / 0.5
            color = color < colorTarget ? min(color + change, colorTarget) : max(color - change, colorTarget)
            instance.setValue(of: NumberProperty(path: "color"), to: Float(color * color * (3 - 2 * color)))
        }
        if moved.isEmpty, !isFading { link?.isPaused = true }
    }
}

/// CADisplayLink retains its target, so it holds this instead of the rig, and stops when the rig is gone.
@MainActor
private final class LinkProxy: NSObject {
    private weak var rig: FaceRig?
    init(_ rig: FaceRig) { self.rig = rig }

    @objc func tick(_ link: CADisplayLink) {
        guard let rig else { return link.invalidate() }
        rig.step(by: min(link.targetTimestamp - link.timestamp, 1.0 / 30))
    }
}

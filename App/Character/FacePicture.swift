import Metal
import RiveRuntime
import UIKit

/// Draws stills of a face off screen. Each one uses a fresh character with its exact values,
/// so a picture never catches a blink or a face on the move.
@MainActor
struct FacePicture {
    enum Failure: Error { case noDevice, notDrawn, unreadable }

    let file: File
    private static let side = 360

    func thumbnails(of parameters: FaceParameters) async throws -> Thumbnails {
        try await Thumbnails(plain: draw(parameters, color: 0), color: draw(parameters, color: 1))
    }

    private func draw(_ parameters: FaceParameters, color: Float) async throws -> UIImage {
        let artboard = try await file.createArtboard()
        let instance = try await file.createViewModelInstance(.viewModelDefault(from: .artboardDefault(artboard)))
        for p in FaceParameter.allCases {
            instance.setValue(of: NumberProperty(path: p.rawValue), to: Float(parameters[p]))
        }
        instance.setValue(of: NumberProperty(path: "color"), to: color)
        let machine = try await artboard.createStateMachine(binding: instance)
        let rive = try await Rive(file: file, artboard: artboard, stateMachine: machine, backgroundColor: Color(red: 255, green: 255, blue: 255, alpha: 255))
        // Values reach the shapes over a couple of frames. The first blink is nearly three seconds in.
        for _ in 0..<4 { machine.advance(by: 1 / 60) }
        return try await image(of: rive)
    }

    private func image(of rive: Rive) async throws -> UIImage {
        let side = Self.side
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let device = MTLCreateSystemDefaultDevice(), let texture = device.makeTexture(descriptor: descriptor) else { throw Failure.noDevice }

        var configuration = RiveUIRendererConfiguration(rive: rive, drawableSize: CGSize(width: side, height: side))
        configuration.pixelFormat = descriptor.pixelFormat
        let renderer = rive.makeRenderer()
        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, any Error>) in
            renderer.draw(configuration, to: texture, from: device) { buffer in
                buffer.addCompletedHandler { buffer in
                    if let error = buffer.error { done.resume(throwing: error) } else { done.resume() }
                }
            } onSkipped: {
                done.resume(throwing: Failure.notDrawn)
            } onError: { error in
                done.resume(throwing: error)
            }
        }

        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        texture.getBytes(&pixels, bytesPerRow: side * 4, from: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0)
        let layout = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4, space: space,
                                  bitmapInfo: layout, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw Failure.unreadable }
        return UIImage(cgImage: image)
    }
}

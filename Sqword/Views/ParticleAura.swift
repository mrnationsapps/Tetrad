//
//  ParticleAura.swift
//  Sqword
//
//  Created by kevin nations on 10/9/25.
//

import SwiftUI

/// Radial “slow explosion” aura.
/// Edit `ParticleAura.defaults` to change look/speed globally.
public struct ParticleAura: View {

    // MARK: Defaults (single source of truth)
    public struct Defaults {
        // Geometry
        public let padding: CGFloat = 10              // inner padding
        public let radiusMultiplier: CGFloat = 1.5    // >1 grows radius
        public let maxRadius: CGFloat? = nil          // optional hard cap

        // Particles
        public let count: Int = 34
        public let size: CGFloat = 8.5
        public let tint: Color = .yellow
        public let blendNormal: Bool = false          // false → additive glow

        // Motion (global)
        public let speed: Double = 0.25               // lower = slower bloom & wobble

        // Motion (per-particle variance)
        public let speedJitter: Double = 0.0          // keep 0.0 to ensure stable speed
        public let wiggle: CGFloat = 8.0              // wobble amplitude (px)
        public let wobbleFreq: Double = 1.0           // wobble frequency (Hz-ish)
        public let wobbleAmp: Double = 6.0            // wobble amplitude used in math

        // Trails
        public let tailScale1: CGFloat = 0.73
        public let tailScale2: CGFloat = 0.50

        // Fade
        public let alphaPower: Double = 0.6           // <1 slower fade, >1 faster
        public let alphaScale: Double = 1.0           // overall brightness
        public let alphaFloor: Double = 0.0           // minimum alpha (0 = full fade)
    }

    /// 🔴 Change this and every aura instance follows.
    public static var defaults = Defaults()

    public init() {}

    // MARK: Internals
    @State private var params: [Param] = []

    private struct Param {
        let angle: Double
        let phase0: Double
        let speedMul: Double
        let wobblePhase: Double
        let wobbleFreq: Double
        let wobbleAmp: Double
    }

    private func makeParams(_ n: Int, _ d: Defaults) -> [Param] {
        let N = max(1, n)
        return (0..<N).map { i in
            let baseAngle = Double(i) * (2 * .pi) / Double(N)
            return Param(
                angle: baseAngle,
                phase0: fmod(Double(i) * 0.381966011, 1.0), // golden-ratio offset
                speedMul: 1.0,                              // unified timebase
                wobblePhase: Double(i) * 0.37,
                wobbleFreq: d.wobbleFreq,
                wobbleAmp: d.wobbleAmp
            )
        }
    }

    // MARK: Body
    public var body: some View {
        GeometryReader { _ in
            TimelineView(.periodic(from: Date(), by: 1.0 / 60.0)) { tl in
                Canvas { ctx, size in
                    let d = Self.defaults
                    let tScaled = tl.date.timeIntervalSinceReferenceDate * max(0.0001, d.speed)
                    ctx.blendMode = d.blendNormal ? .normal : .plusLighter

                    // Canvas geometry
                    let w = size.width, h = size.height
                    let cx = w / 2.0, cy = h / 2.0
                    let baseR   = max(0, min(w, h) / 2.0 - d.padding)
                    let maxR    = min(baseR * d.radiusMultiplier, d.maxRadius ?? .greatestFiniteMagnitude)
                    let edge    = max(d.size * 1.5, 2)

                    // Params (deterministic)
                    let ps = (params.count == d.count) ? params : makeParams(d.count, d)

                    for p in ps {
                        // 0→1 progress, eased
                        let prog  = fmod(tScaled * p.speedMul + p.phase0, 1.0)
                        let eased = 1 - pow(1 - prog, 1.6)

                        // Outward radius with wobble (same global timebase)
                        let wobble = sin(tScaled * p.wobbleFreq + p.wobblePhase) * p.wobbleAmp
                        let r = max(0, min(maxR - edge, eased * maxR + CGFloat(wobble)))

                        let x = cx + CGFloat(cos(p.angle)) * r
                        let y = cy + CGFloat(sin(p.angle)) * r

                        // Alpha curve
                        let fade  = pow(max(0, 1 - eased), d.alphaPower)
                        let alpha = d.alphaFloor + (1 - d.alphaFloor) * fade * d.alphaScale

                        // Core
                        let coreR: CGFloat = d.size
                        ctx.opacity = alpha
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - coreR, y: y - coreR, width: coreR * 2, height: coreR * 2)),
                            with: .color(d.tint)
                        )

                        // Trails toward center
                        func trail(_ back: Double, _ scale: CGFloat, _ mult: Double) {
                            let tProg = max(0, eased - back)
                            let tr = max(0, min(maxR - edge, tProg * maxR))
                            let tx = cx + CGFloat(cos(p.angle)) * tr
                            let ty = cy + CGFloat(sin(p.angle)) * tr
                            let sr = coreR * scale
                            ctx.opacity = alpha * mult
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: tx - sr, y: ty - sr, width: sr * 2, height: sr * 2)),
                                with: .color(d.tint)
                            )
                        }
                        trail(0.08, d.tailScale1, 0.45)
                        trail(0.16, d.tailScale2, 0.25)
                    }
                }
            }
        }
        .onAppear {
            let d = Self.defaults
            if params.count != d.count { params = makeParams(d.count, d) }
        }
        .allowsHitTesting(false)
    }
}

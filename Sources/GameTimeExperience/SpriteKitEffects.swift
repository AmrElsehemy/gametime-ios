import SpriteKit

/// Reusable SpriteKit choreography for Game Time titles.
///
/// These helpers intentionally operate on presentation nodes only. Game rules and
/// deterministic state should never depend on them.
public enum GameTimeMotion {
    /// A tactile placement response: fast anticipation, overshoot and settle.
    public static func placementPop(
        from initialScale: CGFloat = 0.72,
        overshoot: CGFloat = 1.10
    ) -> SKAction {
        .sequence([
            .scale(to: initialScale, duration: 0),
            .group([
                .fadeIn(withDuration: 0.08),
                .scale(to: overshoot, duration: 0.10)
            ]),
            .scale(to: 0.98, duration: 0.07),
            .scale(to: 1.0, duration: 0.08)
        ])
    }

    /// A short spatial rejection response suitable for illegal/conflicting input.
    public static func invalidShake(distance: CGFloat = 6) -> SKAction {
        .sequence([
            .moveBy(x: -distance, y: 0, duration: 0.04),
            .moveBy(x: distance * 2, y: 0, duration: 0.07),
            .moveBy(x: -distance * 1.5, y: 0, duration: 0.06),
            .moveBy(x: distance * 0.5, y: 0, duration: 0.045)
        ])
    }

    /// A compact success pulse for a board cell/piece.
    public static func successPulse(scale: CGFloat = 1.05) -> SKAction {
        .sequence([
            .scale(to: scale, duration: 0.10),
            .scale(to: 1.0, duration: 0.18)
        ])
    }

    /// Stronger milestone treatment without requiring game-specific artwork.
    public static func milestonePulse() -> SKAction {
        .sequence([
            .scale(to: 1.10, duration: 0.12),
            .scale(to: 0.97, duration: 0.08),
            .scale(to: 1.04, duration: 0.08),
            .scale(to: 1.0, duration: 0.12)
        ])
    }

    public static func levelExit(direction: CGFloat = -1) -> SKAction {
        .group([
            .moveBy(x: direction * 34, y: 0, duration: 0.18),
            .fadeOut(withDuration: 0.16),
            .scale(to: 0.97, duration: 0.18)
        ])
    }

    public static func levelEnter(direction: CGFloat = 1) -> SKAction {
        .sequence([
            .group([
                .moveBy(x: direction * 26, y: 0, duration: 0),
                .fadeOut(withDuration: 0),
                .scale(to: 0.98, duration: 0)
            ]),
            .group([
                .moveBy(x: direction * -26, y: 0, duration: 0.22),
                .fadeIn(withDuration: 0.18),
                .scale(to: 1.0, duration: 0.22)
            ])
        ])
    }

    /// Deterministic delays for grid/board cascade choreography.
    public static func staggerOffsets(count: Int, step: TimeInterval) -> [TimeInterval] {
        guard count > 0 else { return [] }
        return (0..<count).map { TimeInterval($0) * max(0, step) }
    }

    /// Runs the same action across nodes with a deterministic stagger.
    public static func runStaggered(
        _ action: SKAction,
        on nodes: [SKNode],
        step: TimeInterval = 0.025
    ) {
        let offsets = staggerOffsets(count: nodes.count, step: step)
        for (node, delay) in zip(nodes, offsets) {
            node.run(.sequence([.wait(forDuration: delay), action.copy() as! SKAction]))
        }
    }
}

public enum GameBurstStyle: Sendable {
    case success
    case milestone
}

/// Lightweight reusable particle burst. Games provide color/art direction;
/// GameTimeExperience owns the lifecycle and choreography.
public enum GameTimeParticles {
    public static func burst(
        color: SKColor,
        style: GameBurstStyle = .success
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.particleBirthRate = style == .milestone ? 180 : 110
        emitter.numParticlesToEmit = style == .milestone ? 44 : 24
        emitter.particleLifetime = style == .milestone ? 0.90 : 0.62
        emitter.particleLifetimeRange = 0.16
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = style == .milestone ? 150 : 105
        emitter.particleSpeedRange = 48
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -1.35
        emitter.particleScale = style == .milestone ? 0.09 : 0.065
        emitter.particleScaleRange = 0.025
        emitter.particleScaleSpeed = -0.045
        emitter.zPosition = 100
        return emitter
    }

    /// Adds a one-shot burst and removes the emitter after all particles expire.
    public static func playBurst(
        in parent: SKNode,
        at position: CGPoint,
        color: SKColor,
        style: GameBurstStyle = .success
    ) {
        let emitter = burst(color: color, style: style)
        emitter.position = position
        parent.addChild(emitter)
        let lifetime: TimeInterval = style == .milestone ? 1.2 : 0.9
        emitter.run(.sequence([.wait(forDuration: lifetime), .removeFromParent()]))
    }
}

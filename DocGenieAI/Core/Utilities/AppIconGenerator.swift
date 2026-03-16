import UIKit

enum AppIconGenerator {
    /// Renders a polished 1024x1024 app icon.
    /// Design: deep gradient background, centered glowing document with magic lamp glow, AI sparkles.
    static func generateIcon(size: CGFloat = 1024) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.image { context in
            let ctx = context.cgContext

            // ── 1. Deep rich gradient background ───────────────────────
            let bgColors = [
                UIColor(red: 0.035, green: 0.047, blue: 0.098, alpha: 1.0).cgColor, // Deep navy
                UIColor(red: 0.082, green: 0.106, blue: 0.220, alpha: 1.0).cgColor, // Mid navy
                UIColor(red: 0.125, green: 0.098, blue: 0.255, alpha: 1.0).cgColor  // Deep purple
            ]
            let bgGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: bgColors as CFArray,
                locations: [0.0, 0.55, 1.0]
            )!
            // Fill entire canvas first to prevent any black areas
            ctx.setFillColor(UIColor(red: 0.125, green: 0.098, blue: 0.255, alpha: 1.0).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            ctx.drawLinearGradient(
                bgGradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size * 0.6, y: size),
                options: []
            )

            // ── 2. Central magic glow (behind document) ────────────────
            // Large indigo/blue ambient glow
            let centralGlowColors = [
                UIColor(red: 0.30, green: 0.35, blue: 0.95, alpha: 0.28).cgColor,
                UIColor(red: 0.30, green: 0.35, blue: 0.95, alpha: 0.08).cgColor,
                UIColor(red: 0.30, green: 0.35, blue: 0.95, alpha: 0.0).cgColor
            ]
            let centralGlow = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: centralGlowColors as CFArray,
                locations: [0.0, 0.5, 1.0]
            )!
            ctx.drawRadialGradient(
                centralGlow,
                startCenter: CGPoint(x: size * 0.50, y: size * 0.48),
                startRadius: 0,
                endCenter: CGPoint(x: size * 0.50, y: size * 0.48),
                endRadius: size * 0.50,
                options: []
            )

            // Warm cyan accent glow (top-right, where sparkles cluster)
            let cyanGlowColors = [
                UIColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 0.15).cgColor,
                UIColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 0.0).cgColor
            ]
            let cyanGlow = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cyanGlowColors as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.drawRadialGradient(
                cyanGlow,
                startCenter: CGPoint(x: size * 0.68, y: size * 0.28),
                startRadius: 0,
                endCenter: CGPoint(x: size * 0.68, y: size * 0.28),
                endRadius: size * 0.30,
                options: []
            )

            // ── 3. Document — centered, prominent ──────────────────────
            let docWidth = size * 0.46
            let docHeight = size * 0.56
            let docX = (size - docWidth) / 2 - size * 0.02 // Slightly left to balance sparkles
            let docY = (size - docHeight) / 2 + size * 0.02
            let foldSize = size * 0.08
            let cornerRadius = size * 0.03

            // Build document path with folded corner
            let docPath = UIBezierPath()
            // Start from top-left (after corner radius)
            docPath.move(to: CGPoint(x: docX + cornerRadius, y: docY))
            // Top edge to fold point
            docPath.addLine(to: CGPoint(x: docX + docWidth - foldSize, y: docY))
            // Fold diagonal
            docPath.addLine(to: CGPoint(x: docX + docWidth, y: docY + foldSize))
            // Right edge
            docPath.addLine(to: CGPoint(x: docX + docWidth, y: docY + docHeight - cornerRadius))
            // Bottom-right corner
            docPath.addArc(
                withCenter: CGPoint(x: docX + docWidth - cornerRadius, y: docY + docHeight - cornerRadius),
                radius: cornerRadius, startAngle: 0, endAngle: .pi / 2, clockwise: true
            )
            // Bottom edge
            docPath.addLine(to: CGPoint(x: docX + cornerRadius, y: docY + docHeight))
            // Bottom-left corner
            docPath.addArc(
                withCenter: CGPoint(x: docX + cornerRadius, y: docY + docHeight - cornerRadius),
                radius: cornerRadius, startAngle: .pi / 2, endAngle: .pi, clockwise: true
            )
            // Left edge
            docPath.addLine(to: CGPoint(x: docX, y: docY + cornerRadius))
            // Top-left corner
            docPath.addArc(
                withCenter: CGPoint(x: docX + cornerRadius, y: docY + cornerRadius),
                radius: cornerRadius, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true
            )
            docPath.close()

            // Document drop shadow
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: size * 0.015),
                blur: size * 0.06,
                color: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.6).cgColor
            )
            ctx.setFillColor(UIColor(white: 0, alpha: 0.01).cgColor)
            ctx.addPath(docPath.cgPath)
            ctx.fillPath()
            ctx.restoreGState()

            // Document gradient fill — glass-like translucent
            ctx.saveGState()
            ctx.addPath(docPath.cgPath)
            ctx.clip()
            let docFillColors = [
                UIColor(red: 0.85, green: 0.87, blue: 0.97, alpha: 0.22).cgColor,
                UIColor(red: 0.55, green: 0.58, blue: 0.90, alpha: 0.10).cgColor,
                UIColor(red: 0.35, green: 0.38, blue: 0.80, alpha: 0.06).cgColor
            ]
            let docFillGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: docFillColors as CFArray,
                locations: [0.0, 0.5, 1.0]
            )!
            ctx.drawLinearGradient(
                docFillGradient,
                start: CGPoint(x: docX, y: docY),
                end: CGPoint(x: docX + docWidth * 0.3, y: docY + docHeight),
                options: []
            )
            ctx.restoreGState()

            // Document border — bright indigo stroke
            ctx.saveGState()
            ctx.setStrokeColor(UIColor(red: 0.45, green: 0.48, blue: 0.98, alpha: 0.70).cgColor)
            ctx.setLineWidth(size * 0.005)
            ctx.addPath(docPath.cgPath)
            ctx.strokePath()
            ctx.restoreGState()

            // Inner highlight edge (top-left shine)
            ctx.saveGState()
            ctx.addPath(docPath.cgPath)
            ctx.clip()
            let shineColors = [
                UIColor(white: 1.0, alpha: 0.12).cgColor,
                UIColor(white: 1.0, alpha: 0.0).cgColor
            ]
            let shineGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: shineColors as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.drawLinearGradient(
                shineGradient,
                start: CGPoint(x: docX, y: docY),
                end: CGPoint(x: docX + docWidth * 0.5, y: docY + docHeight * 0.5),
                options: []
            )
            ctx.restoreGState()

            // ── 4. Fold corner triangle ────────────────────────────────
            let foldTriangle = UIBezierPath()
            foldTriangle.move(to: CGPoint(x: docX + docWidth - foldSize, y: docY))
            foldTriangle.addLine(to: CGPoint(x: docX + docWidth - foldSize, y: docY + foldSize))
            foldTriangle.addLine(to: CGPoint(x: docX + docWidth, y: docY + foldSize))
            foldTriangle.close()

            // Fold fill — slightly darker
            ctx.saveGState()
            ctx.addPath(foldTriangle.cgPath)
            ctx.clip()
            let foldColors = [
                UIColor(red: 0.25, green: 0.28, blue: 0.55, alpha: 0.50).cgColor,
                UIColor(red: 0.15, green: 0.17, blue: 0.38, alpha: 0.65).cgColor
            ]
            let foldGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: foldColors as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.drawLinearGradient(
                foldGradient,
                start: CGPoint(x: docX + docWidth - foldSize, y: docY),
                end: CGPoint(x: docX + docWidth, y: docY + foldSize),
                options: []
            )
            ctx.restoreGState()

            // Fold border lines
            ctx.setStrokeColor(UIColor(red: 0.45, green: 0.48, blue: 0.98, alpha: 0.40).cgColor)
            ctx.setLineWidth(size * 0.003)
            let foldLine = UIBezierPath()
            foldLine.move(to: CGPoint(x: docX + docWidth - foldSize, y: docY))
            foldLine.addLine(to: CGPoint(x: docX + docWidth - foldSize, y: docY + foldSize))
            foldLine.addLine(to: CGPoint(x: docX + docWidth, y: docY + foldSize))
            ctx.addPath(foldLine.cgPath)
            ctx.strokePath()

            // ── 5. Text lines — higher contrast, well-spaced ───────────
            let lineStartX = docX + size * 0.045
            let lineWidths: [CGFloat] = [0.72, 0.60, 0.66, 0.48, 0.55]
            let lineHeight = size * 0.016
            let lineSpacing = size * 0.046
            let firstLineY = docY + size * 0.12

            for i in 0..<5 {
                let lineY = firstLineY + CGFloat(i) * lineSpacing
                let w = docWidth * lineWidths[i]
                let lineRect = CGRect(x: lineStartX, y: lineY, width: w, height: lineHeight)
                let linePath = UIBezierPath(roundedRect: lineRect, cornerRadius: lineHeight / 2)

                // Alternating subtle opacity for visual rhythm
                let alpha: CGFloat = (i % 2 == 0) ? 0.45 : 0.32
                ctx.setFillColor(UIColor(white: 1.0, alpha: alpha).cgColor)
                ctx.addPath(linePath.cgPath)
                ctx.fillPath()
            }

            // ── 6. AI sparkles with glow halos ─────────────────────────
            // Primary sparkle (large, bright cyan) — top-right
            drawSparkleWithGlow(
                ctx: ctx, size: size,
                center: CGPoint(x: size * 0.73, y: size * 0.25),
                armLength: size * 0.09,
                color: UIColor(red: 0.0, green: 0.88, blue: 0.87, alpha: 1.0),
                glowRadius: size * 0.07,
                glowAlpha: 0.30
            )

            // Secondary sparkle (medium, bright indigo-white)
            drawSparkleWithGlow(
                ctx: ctx, size: size,
                center: CGPoint(x: size * 0.79, y: size * 0.50),
                armLength: size * 0.058,
                color: UIColor(red: 0.58, green: 0.62, blue: 1.0, alpha: 0.95),
                glowRadius: size * 0.045,
                glowAlpha: 0.22
            )

            // Tertiary sparkle (small, warm purple)
            drawSparkleWithGlow(
                ctx: ctx, size: size,
                center: CGPoint(x: size * 0.58, y: size * 0.17),
                armLength: size * 0.04,
                color: UIColor(red: 0.72, green: 0.58, blue: 1.0, alpha: 0.90),
                glowRadius: size * 0.03,
                glowAlpha: 0.18
            )

            // Tiny accent sparkle (cyan)
            drawSparkleWithGlow(
                ctx: ctx, size: size,
                center: CGPoint(x: size * 0.85, y: size * 0.34),
                armLength: size * 0.024,
                color: UIColor(red: 0.0, green: 0.78, blue: 0.88, alpha: 0.75),
                glowRadius: size * 0.018,
                glowAlpha: 0.14
            )

            // Bottom-left subtle sparkle (adds balance)
            drawSparkleWithGlow(
                ctx: ctx, size: size,
                center: CGPoint(x: size * 0.22, y: size * 0.72),
                armLength: size * 0.028,
                color: UIColor(red: 0.50, green: 0.55, blue: 0.95, alpha: 0.55),
                glowRadius: size * 0.02,
                glowAlpha: 0.10
            )

            // ── 7. Floating particles (tiny dots for depth) ────────────
            let particles: [(x: CGFloat, y: CGFloat, radius: CGFloat, alpha: CGFloat)] = [
                (0.30, 0.18, 0.006, 0.35),
                (0.82, 0.65, 0.005, 0.28),
                (0.18, 0.55, 0.004, 0.22),
                (0.75, 0.75, 0.005, 0.25),
                (0.40, 0.82, 0.004, 0.20),
                (0.88, 0.18, 0.003, 0.18),
                (0.15, 0.35, 0.003, 0.15),
            ]
            for p in particles {
                let center = CGPoint(x: size * p.x, y: size * p.y)
                let radius = size * p.radius
                ctx.setFillColor(UIColor(red: 0.60, green: 0.65, blue: 1.0, alpha: p.alpha).cgColor)
                ctx.fillEllipse(in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
        }
    }

    // MARK: - Sparkle with Glow Halo

    private static func drawSparkleWithGlow(
        ctx: CGContext, size: CGFloat,
        center: CGPoint, armLength: CGFloat,
        color: UIColor,
        glowRadius: CGFloat, glowAlpha: CGFloat
    ) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let glowColors = [
            UIColor(red: r, green: g, blue: b, alpha: glowAlpha).cgColor,
            UIColor(red: r, green: g, blue: b, alpha: glowAlpha * 0.3).cgColor,
            UIColor(red: r, green: g, blue: b, alpha: 0.0).cgColor
        ]
        let glowGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: glowColors as CFArray,
            locations: [0.0, 0.4, 1.0]
        )!
        ctx.drawRadialGradient(
            glowGradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: glowRadius + armLength,
            options: []
        )

        drawSparkle(ctx: ctx, center: center, armLength: armLength, color: color)
    }

    private static func drawSparkle(ctx: CGContext, center: CGPoint, armLength: CGFloat, color: UIColor) {
        ctx.setFillColor(color.cgColor)
        let crossWidth = armLength * 0.20
        let path = UIBezierPath()

        // Vertical arm
        path.move(to: CGPoint(x: center.x, y: center.y - armLength))
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + armLength),
            controlPoint: CGPoint(x: center.x + crossWidth, y: center.y)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y - armLength),
            controlPoint: CGPoint(x: center.x - crossWidth, y: center.y)
        )
        path.close()

        // Horizontal arm
        path.move(to: CGPoint(x: center.x - armLength, y: center.y))
        path.addQuadCurve(
            to: CGPoint(x: center.x + armLength, y: center.y),
            controlPoint: CGPoint(x: center.x, y: center.y + crossWidth)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x - armLength, y: center.y),
            controlPoint: CGPoint(x: center.x, y: center.y - crossWidth)
        )
        path.close()

        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }
}

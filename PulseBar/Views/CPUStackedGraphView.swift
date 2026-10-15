import SwiftUI

/// Stacked CPU history: user load (blue) from the baseline, system load (red)
/// as a band on top of it. Translucent fills so it sits naturally on glass.
public struct CPUStackedGraphView: View {
    public let userPoints: [Double]
    public let sysPoints: [Double]
    public let height: CGFloat

    public init(userPoints: [Double], sysPoints: [Double], height: CGFloat = 80) {
        self.userPoints = userPoints
        self.sysPoints = sysPoints
        self.height = height
    }

    public var body: some View {
        Canvas { context, size in
            let count = max(userPoints.count, sysPoints.count)
            guard count >= 1 else { return }

            var user = (0..<count).map { i in
                userPoints.indices.contains(i) ? min(100.0, max(0, userPoints[i])) : 0
            }
            var total = (0..<count).map { i in
                min(100.0, user[i] + (sysPoints.indices.contains(i) ? max(0, sysPoints[i]) : 0))
            }

            let xs: [CGFloat]
            if count == 1 {
                // A single sample draws as a flat line across the graph.
                xs = [0, size.width]
                user.append(user[0])
                total.append(total[0])
            } else {
                xs = (0..<count).map { CGFloat($0) * size.width / CGFloat(count - 1) }
            }

            func y(_ value: Double) -> CGFloat {
                size.height - CGFloat(value / 100.0) * (size.height - 4) - 2
            }
            let userPts = zip(xs, user).map { CGPoint(x: $0, y: y($1)) }
            let totalPts = zip(xs, total).map { CGPoint(x: $0, y: y($1)) }

            var userLine = Path()
            userLine.addLines(userPts)
            var totalLine = Path()
            totalLine.addLines(totalPts)

            var userArea = userLine
            userArea.addLine(to: CGPoint(x: size.width, y: size.height))
            userArea.addLine(to: CGPoint(x: 0, y: size.height))
            userArea.closeSubpath()

            // System band: between the total line and the user line.
            var systemBand = totalLine
            for point in userPts.reversed() {
                systemBand.addLine(to: point)
            }
            systemBand.closeSubpath()

            let top = CGPoint(x: 0, y: 0)
            let bottom = CGPoint(x: 0, y: size.height)
            context.fill(
                systemBand,
                with: .linearGradient(
                    Gradient(colors: [DesignTokens.cpuSystem.opacity(0.55), DesignTokens.cpuSystem.opacity(0.25)]),
                    startPoint: top,
                    endPoint: bottom
                )
            )
            context.fill(
                userArea,
                with: .linearGradient(
                    Gradient(colors: [DesignTokens.cpuUser.opacity(0.6), DesignTokens.cpuUser.opacity(0.15)]),
                    startPoint: top,
                    endPoint: bottom
                )
            )

            let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            context.stroke(totalLine, with: .color(DesignTokens.cpuSystem), style: stroke)
            context.stroke(userLine, with: .color(DesignTokens.cpuUser), style: stroke)
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.28), value: userPoints.last)
        .animation(.easeInOut(duration: 0.28), value: sysPoints.last)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("CPU history graph, user and system load")
    }
}

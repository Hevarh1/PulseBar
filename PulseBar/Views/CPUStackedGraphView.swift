import SwiftUI

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

            let stepX = count > 1 ? size.width / CGFloat(count - 1) : size.width

            // 1. Draw Total (User + System) Area with Red
            var totalPath = Path()
            var totalLine = Path()

            let firstUser = userPoints.indices.contains(0) ? userPoints[0] : 0
            let firstSys = sysPoints.indices.contains(0) ? sysPoints[0] : 0
            let firstTotal = min(100.0, firstUser + firstSys)
            let firstY = size.height - (CGFloat(firstTotal / 100.0) * (size.height - 4)) - 2

            totalPath.move(to: CGPoint(x: 0, y: size.height))
            totalPath.addLine(to: CGPoint(x: 0, y: firstY))
            totalLine.move(to: CGPoint(x: 0, y: firstY))

            if count == 1 {
                totalPath.addLine(to: CGPoint(x: size.width, y: firstY))
                totalLine.addLine(to: CGPoint(x: size.width, y: firstY))
            } else {
                for i in 1..<count {
                    let u = userPoints.indices.contains(i) ? userPoints[i] : 0
                    let s = sysPoints.indices.contains(i) ? sysPoints[i] : 0
                    let tot = min(100.0, u + s)
                    let y = size.height - (CGFloat(tot / 100.0) * (size.height - 4)) - 2
                    let x = CGFloat(i) * stepX
                    totalPath.addLine(to: CGPoint(x: x, y: y))
                    totalLine.addLine(to: CGPoint(x: x, y: y))
                }
            }
            totalPath.addLine(to: CGPoint(x: size.width, y: size.height))
            totalPath.closeSubpath()

            // Fill System area with red / coral
            context.fill(
                totalPath,
                with: .color(Color(red: 0.95, green: 0.30, blue: 0.30).opacity(0.85))
            )

            // 2. Draw User Area with Blue on top of bottom
            var userPath = Path()
            var userLine = Path()

            let firstUserY = size.height - (CGFloat(firstUser / 100.0) * (size.height - 4)) - 2
            userPath.move(to: CGPoint(x: 0, y: size.height))
            userPath.addLine(to: CGPoint(x: 0, y: firstUserY))
            userLine.move(to: CGPoint(x: 0, y: firstUserY))

            if count == 1 {
                userPath.addLine(to: CGPoint(x: size.width, y: firstUserY))
                userLine.addLine(to: CGPoint(x: size.width, y: firstUserY))
            } else {
                for i in 1..<count {
                    let u = userPoints.indices.contains(i) ? userPoints[i] : 0
                    let y = size.height - (CGFloat(u / 100.0) * (size.height - 4)) - 2
                    let x = CGFloat(i) * stepX
                    userPath.addLine(to: CGPoint(x: x, y: y))
                    userLine.addLine(to: CGPoint(x: x, y: y))
                }
            }
            userPath.addLine(to: CGPoint(x: size.width, y: size.height))
            userPath.closeSubpath()

            // Fill User area with blue
            context.fill(
                userPath,
                with: .color(Color(red: 0.20, green: 0.60, blue: 1.0).opacity(0.95))
            )

            // Draw line strokes
            context.stroke(totalLine, with: .color(Color(red: 1.0, green: 0.4, blue: 0.4)), lineWidth: 1.5)
            context.stroke(userLine, with: .color(Color(red: 0.35, green: 0.75, blue: 1.0)), lineWidth: 1.5)
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.07, green: 0.11, blue: 0.16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.28), value: userPoints.last)
        .animation(.easeInOut(duration: 0.28), value: sysPoints.last)
    }
}

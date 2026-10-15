import SwiftUI

public struct GraphView: View {
    public let dataPoints: [Double]
    public let maxValue: Double
    public let strokeColor: Color
    public let gradientColors: [Color]
    public let height: CGFloat

    public init(
        dataPoints: [Double],
        maxValue: Double = 100.0,
        strokeColor: Color = .blue,
        gradientColors: [Color] = [.blue.opacity(0.4), .blue.opacity(0.0)],
        height: CGFloat = 48
    ) {
        self.dataPoints = dataPoints
        self.maxValue = maxValue > 0 ? maxValue : 100.0
        self.strokeColor = strokeColor
        self.gradientColors = gradientColors
        self.height = height
    }

    public var body: some View {
        Canvas { context, size in
            guard let latest = dataPoints.last else { return }

            let points: [CGPoint]
            if dataPoints.count == 1 {
                let y = yPosition(for: latest, in: size)
                points = [CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y)]
            } else {
                let stepX = size.width / CGFloat(dataPoints.count - 1)
                points = dataPoints.enumerated().map { index, val in
                    CGPoint(x: CGFloat(index) * stepX, y: yPosition(for: val, in: size))
                }
            }

            // Path for gradient fill
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: points[0].x, y: size.height))
            for pt in points {
                fillPath.addLine(to: pt)
            }
            fillPath.addLine(to: CGPoint(x: points.last!.x, y: size.height))
            fillPath.closeSubpath()

            let fillGradient = Gradient(colors: gradientColors)
            context.fill(
                fillPath,
                with: .linearGradient(
                    fillGradient,
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            // Path for line stroke
            var linePath = Path()
            linePath.move(to: points[0])
            for pt in points.dropFirst() {
                linePath.addLine(to: pt)
            }

            context.stroke(
                linePath,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.28), value: dataPoints.last)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("History graph with \(dataPoints.count) data points, latest value \(Int(dataPoints.last ?? 0))")
    }

    private func yPosition(for value: Double, in size: CGSize) -> CGFloat {
        let clamped = max(0.0, min(maxValue, value))
        let normalizedY = 1.0 - (clamped / maxValue)
        return CGFloat(normalizedY) * (size.height - 4) + 2
    }
}

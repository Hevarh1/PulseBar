import SwiftUI

public struct StorageCard: View {
    public let disk: DiskSample

    public init(disk: DiskSample) {
        self.disk = disk
    }

    public var body: some View {
        MetricCard(
            title: "Storage",
            icon: "internaldrive",
            iconColor: .teal,
            detailsText: "Volume: \(disk.volumeName)\nTotal: \(Formatters.formatDiskBytes(disk.totalBytes))\nUsed: \(Formatters.formatDiskBytes(disk.usedBytes))\nFree: \(Formatters.formatDiskBytes(disk.freeBytes))\nRead Rate: \(Formatters.formatRate(disk.readBytesPerSec))\nWrite Rate: \(Formatters.formatRate(disk.writeBytesPerSec))"
        ) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(disk.volumeName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Formatters.formatDiskBytes(disk.usedBytes)) / \(Formatters.formatDiskBytes(disk.totalBytes))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }

                // Capacity bar
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    Capsule()
                        .fill(LinearGradient(colors: [.teal, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                        .scaleEffect(x: CGFloat(min(1.0, max(0.0, disk.usedPercentage / 100.0))), y: 1.0, anchor: .leading)
                }
                .frame(height: 6)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9))
                            .foregroundColor(.teal)
                        Text(Formatters.formatRate(disk.readBytesPerSec))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9))
                            .foregroundColor(.teal)
                        Text(Formatters.formatRate(disk.writeBytesPerSec))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(Formatters.formatDiskBytes(disk.freeBytes)) Free")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

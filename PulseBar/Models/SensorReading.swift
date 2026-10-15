import Foundation

public struct SensorReading: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let valueCelsius: Double
    public let location: String
    public let isReliable: Bool

    public init(name: String, valueCelsius: Double, location: String = "Internal", isReliable: Bool = true) {
        self.name = name
        self.valueCelsius = valueCelsius
        self.location = location
        self.isReliable = isReliable
    }
}

import Foundation

public enum DistanceCalculationError:
    Error,
    Sendable,
    Equatable
{
    case nonFiniteCoordinate
    case latitudeOutOfRange
    case longitudeOutOfRange
}

public protocol DistanceCalculating: Sendable {
    func distance(
        from start: GeoPoint,
        to end: GeoPoint
    ) throws -> Double
}

/// Deterministic great-circle distance calculation without CoreLocation.
public struct HaversineDistanceCalculator:
    DistanceCalculating,
    Sendable
{
    public let earthRadiusMeters: Double

    public init(earthRadiusMeters: Double = 6_371_000) {
        self.earthRadiusMeters = earthRadiusMeters
    }

    public func distance(
        from start: GeoPoint,
        to end: GeoPoint
    ) throws -> Double {
        try validate(start)
        try validate(end)
        guard start != end else {
            return 0
        }

        let startLatitude = radians(start.latitude)
        let endLatitude = radians(end.latitude)
        let latitudeDelta = endLatitude - startLatitude
        let longitudeDelta = radians(
            normalizedLongitudeDelta(
                end.longitude - start.longitude
            )
        )
        let sineLatitude = sin(latitudeDelta / 2)
        let sineLongitude = sin(longitudeDelta / 2)
        let haversine = sineLatitude * sineLatitude
            + cos(startLatitude)
            * cos(endLatitude)
            * sineLongitude
            * sineLongitude
        let clamped = min(max(haversine, 0), 1)
        let centralAngle = 2 * atan2(
            sqrt(clamped),
            sqrt(1 - clamped)
        )
        return earthRadiusMeters * centralAngle
    }

    private func validate(_ point: GeoPoint) throws {
        guard point.latitude.isFinite,
              point.longitude.isFinite
        else {
            throw DistanceCalculationError.nonFiniteCoordinate
        }
        guard (-90 ... 90).contains(point.latitude) else {
            throw DistanceCalculationError.latitudeOutOfRange
        }
        guard (-180 ... 180).contains(point.longitude) else {
            throw DistanceCalculationError.longitudeOutOfRange
        }
    }

    private func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private func normalizedLongitudeDelta(
        _ degrees: Double
    ) -> Double {
        var value = degrees.truncatingRemainder(
            dividingBy: 360
        )
        if value > 180 {
            value -= 360
        } else if value < -180 {
            value += 360
        }
        return value
    }
}

public struct GeofenceEvaluator: Sendable, Equatable {
    private let configuration: LocationRiskConfiguration

    public init(
        configuration: LocationRiskConfiguration = .demo
    ) {
        self.configuration = configuration
    }

    public func evaluate(
        distanceMeters: Double,
        destinationRadiusMeters: Double
    ) -> GeofenceState {
        guard distanceMeters.isFinite,
              distanceMeters >= 0,
              destinationRadiusMeters.isFinite,
              destinationRadiusMeters > 0
        else {
            return .outside
        }
        if distanceMeters <= destinationRadiusMeters {
            return .inside
        }
        if distanceMeters
            <= destinationRadiusMeters
            + configuration.approachingBufferMeters {
            return .approaching
        }
        return .outside
    }
}

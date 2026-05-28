// Port of agent-device/src/utils/__tests__/args.test.ts (location coordinate section)

import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/location_coordinates.dart';
import 'package:test/test.dart';

void main() {
  group('readLocationCoordinate', () {
    test('parses valid latitude', () {
      expect(readLocationCoordinate('37.3349', 'latitude'), closeTo(37.3349, 1e-9));
    });

    test('parses valid longitude', () {
      expect(readLocationCoordinate('-122.009', 'longitude'), closeTo(-122.009, 1e-9));
    });

    test('accepts zero', () {
      expect(readLocationCoordinate('0', 'latitude'), 0.0);
      expect(readLocationCoordinate('0', 'longitude'), 0.0);
    });

    test('accepts boundary values for latitude', () {
      expect(readLocationCoordinate('90', 'latitude'), 90.0);
      expect(readLocationCoordinate('-90', 'latitude'), -90.0);
    });

    test('accepts boundary values for longitude', () {
      expect(readLocationCoordinate('180', 'longitude'), 180.0);
      expect(readLocationCoordinate('-180', 'longitude'), -180.0);
    });

    test('throws for null value', () {
      expect(
        () => readLocationCoordinate(null, 'latitude'),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('settings location set requires latitude'),
          ),
        ),
      );
    });

    test('throws for empty string', () {
      expect(
        () => readLocationCoordinate('', 'longitude'),
        throwsA(isA<AppError>()),
      );
    });

    test('throws for latitude out of range', () {
      expect(
        () => readLocationCoordinate('91', 'latitude'),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('latitude must be a number from -90 to 90'),
          ),
        ),
      );
    });

    test('throws for longitude out of range', () {
      expect(
        () => readLocationCoordinate('181', 'longitude'),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('longitude must be a number from -180 to 180'),
          ),
        ),
      );
    });

    test('throws for non-numeric value', () {
      expect(
        () => readLocationCoordinate('abc', 'latitude'),
        throwsA(isA<AppError>()),
      );
    });
  });

  group('requireLocationCoordinates', () {
    test('returns coordinates when both are valid', () {
      final coords = requireLocationCoordinates(37.3349, -122.009);
      expect(coords.latitude, closeTo(37.3349, 1e-9));
      expect(coords.longitude, closeTo(-122.009, 1e-9));
    });

    test('throws when latitude is null', () {
      expect(
        () => requireLocationCoordinates(null, -122.009),
        throwsA(isA<AppError>()),
      );
    });

    test('throws when longitude is null', () {
      expect(
        () => requireLocationCoordinates(37.3349, null),
        throwsA(isA<AppError>()),
      );
    });

    test('throws when latitude is out of range', () {
      expect(
        () => requireLocationCoordinates(91.0, 0.0),
        throwsA(isA<AppError>()),
      );
    });

    test('throws when longitude is out of range', () {
      expect(
        () => requireLocationCoordinates(0.0, -181.0),
        throwsA(isA<AppError>()),
      );
    });
  });
}

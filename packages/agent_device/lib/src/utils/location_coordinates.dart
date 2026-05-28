// Port of agent-device/src/utils/location-coordinates.ts

import 'errors.dart';

typedef LocationCoordinateLabel = String;

/// Parsed latitude/longitude coordinate pair.
class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates({required this.latitude, required this.longitude});
}

/// Parse and validate a coordinate value from a CLI positional string.
///
/// Throws [AppError] if [value] is null/empty or out of valid range.
double readLocationCoordinate(
  String? value,
  LocationCoordinateLabel label,
) {
  if (value == null || value.trim().isEmpty) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'settings location set requires $label',
    );
  }
  final parsed = double.tryParse(value);
  if (parsed == null) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      '$label must be a number from ${_min(label)} to ${_max(label)}',
    );
  }
  return _validateLocationCoordinate(parsed, label);
}

/// Validate and return a [LocationCoordinates] from raw nullable values.
///
/// Throws [AppError] if either value is missing or out of valid range.
LocationCoordinates requireLocationCoordinates(
  double? latitude,
  double? longitude,
) {
  return LocationCoordinates(
    latitude: _validateLocationCoordinate(latitude, 'latitude'),
    longitude: _validateLocationCoordinate(longitude, 'longitude'),
  );
}

double _validateLocationCoordinate(
  Object? value,
  LocationCoordinateLabel label,
) {
  final double d;
  if (value is double) {
    d = value;
  } else if (value is int) {
    d = value.toDouble();
  } else {
    throw AppError(
      AppErrorCodes.invalidArgs,
      '$label must be a number from ${_min(label)} to ${_max(label)}',
    );
  }
  if (!d.isFinite || d < _min(label) || d > _max(label)) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      '$label must be a number from ${_min(label)} to ${_max(label)}',
    );
  }
  return d;
}

int _min(LocationCoordinateLabel label) => label == 'latitude' ? -90 : -180;
int _max(LocationCoordinateLabel label) => label == 'latitude' ? 90 : 180;

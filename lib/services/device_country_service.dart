import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DeviceCountry {
  final String countryCode;
  final String countryName;
  final bool fromDeviceLocation;

  const DeviceCountry({
    required this.countryCode,
    required this.countryName,
    required this.fromDeviceLocation,
  });
}

abstract class DeviceCountryService {
  Future<DeviceCountry?> detectCountry();
}

abstract interface class PermissionAwareDeviceCountryService {
  Future<DeviceCountry?> detectCountryIfPermissionGranted();
}

class GeolocatorDeviceCountryService
    implements DeviceCountryService, PermissionAwareDeviceCountryService {
  const GeolocatorDeviceCountryService();

  @override
  Future<DeviceCountry?> detectCountry() async {
    return _detectCountry(requestPermission: true);
  }

  @override
  Future<DeviceCountry?> detectCountryIfPermissionGranted() async {
    return _detectCountry(requestPermission: false);
  }

  Future<DeviceCountry?> _detectCountry({
    required bool requestPermission,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied && requestPermission) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await _position();
          if (position != null) {
            final placemarks = await Geocoding().placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );
            for (final placemark in placemarks) {
              final countryCode = (placemark.isoCountryCode ?? '')
                  .trim()
                  .toUpperCase();
              if (countryCode.length != 2) continue;
              return DeviceCountry(
                countryCode: countryCode,
                countryName: (placemark.country ?? '').trim(),
                fromDeviceLocation: true,
              );
            }
          }
        }
      }
    } catch (error) {
      debugPrint(
        '[DeviceCountryService] Detection failed safely '
        '(${error.runtimeType}).',
      );
    }
    // Locale fallback is resolved by RegionSettingsNotifier, where it retains
    // its lower authority instead of masquerading as device detection.
    return null;
  }

  Future<Position?> _position() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }
}

final deviceCountryServiceProvider = Provider<DeviceCountryService>(
  (_) => const GeolocatorDeviceCountryService(),
);

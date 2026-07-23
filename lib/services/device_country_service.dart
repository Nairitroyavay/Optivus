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

class GeolocatorDeviceCountryService implements DeviceCountryService {
  const GeolocatorDeviceCountryService();

  @override
  Future<DeviceCountry?> detectCountry() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
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
    } catch (error, stackTrace) {
      debugPrint(
        'Device country detection failed; using locale fallback: '
        '$error\n$stackTrace',
      );
    }

    final localeCountryCode =
        PlatformDispatcher.instance.locale.countryCode?.trim().toUpperCase() ??
        '';
    if (localeCountryCode.length != 2) return null;
    return DeviceCountry(
      countryCode: localeCountryCode,
      countryName: '',
      fromDeviceLocation: false,
    );
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

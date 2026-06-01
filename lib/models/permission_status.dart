enum PermissionConnectionState { notConnected, mockConnected, comingLater }

class PermissionStatus {
  final PermissionConnectionState notifications;
  final PermissionConnectionState usageAccess;
  final PermissionConnectionState locationGps;
  final PermissionConnectionState healthConnect;
  final PermissionConnectionState cameraGallery;

  PermissionStatus({
    this.notifications = PermissionConnectionState.notConnected,
    this.usageAccess = PermissionConnectionState.notConnected,
    this.locationGps = PermissionConnectionState.notConnected,
    this.healthConnect = PermissionConnectionState.notConnected,
    this.cameraGallery = PermissionConnectionState.notConnected,
  });

  PermissionStatus copyWith({
    PermissionConnectionState? notifications,
    PermissionConnectionState? usageAccess,
    PermissionConnectionState? locationGps,
    PermissionConnectionState? healthConnect,
    PermissionConnectionState? cameraGallery,
  }) {
    return PermissionStatus(
      notifications: notifications ?? this.notifications,
      usageAccess: usageAccess ?? this.usageAccess,
      locationGps: locationGps ?? this.locationGps,
      healthConnect: healthConnect ?? this.healthConnect,
      cameraGallery: cameraGallery ?? this.cameraGallery,
    );
  }
}

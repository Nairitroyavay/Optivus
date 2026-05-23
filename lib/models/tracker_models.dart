class RoutePoint {
  final double latitude;
  final double longitude;
  final String timestamp;

  RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

class FitnessActivity {
  final String id;
  final String type; // Walk, Run, Cycling
  final double distanceKm;
  final int durationSeconds;
  final double paceMinutesPerKm;
  final int caloriesBurned;
  final List<RoutePoint> route;

  FitnessActivity({
    required this.id,
    required this.type,
    this.distanceKm = 0.0,
    this.durationSeconds = 0,
    this.paceMinutesPerKm = 0.0,
    this.caloriesBurned = 0,
    List<RoutePoint>? route,
  }) : route = route ?? const [];
}

class ScreenTimeApp {
  final String name;
  final String packageName;
  final int durationMinutes;
  final String distractionRisk; // Low, Medium, High

  ScreenTimeApp({
    required this.name,
    required this.packageName,
    required this.durationMinutes,
    required this.distractionRisk,
  });
}

class HydrationLog {
  final String id;
  final int amountMl;
  final String timestamp;

  HydrationLog({
    required this.id,
    required this.amountMl,
    required this.timestamp,
  });
}

class TrackerSession {
  final String id;
  final String category; // Mind, Body, Finance, Focus, Habits
  final String title;
  final DateTime timestamp;
  final int value; // Generic progress value (e.g. minutes, ml, rupees)
  final bool isCompleted;

  TrackerSession({
    required this.id,
    required this.category,
    required this.title,
    required this.timestamp,
    required this.value,
    this.isCompleted = true,
  });
}

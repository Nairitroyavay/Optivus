# Handoff Report — Group J Issues 61 & 62 Exploration

## 1. Observation
- **Issue 61 (iOS Platform Channel Async Error Boundary Safety)**:
  - Inspection of `lib/main.dart` (lines 15–27) revealed raw platform channel calls:
    ```dart
    SystemChrome.setSystemUIOverlayStyle(...);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ```
  - Inspection of `lib/services/native/native_service_adapters.dart` showed abstract platform service definitions and `Fake` implementations awaiting native channel migration.
  - Inspection of `lib/config/firebase_options.dart` (lines 25–53) showed `DefaultFirebaseOptions.currentPlatform` throwing `UnsupportedError` on iOS if unconfigured.
  - Calling unhandled platform channels on iOS or in test runners raises `MissingPluginException` or `PlatformException`.

- **Issue 62 (Android Background Notification Click Intent Payload Recovery)**:
  - Inspection of `android/app/src/main/kotlin/com/nairitroy/optivus/MainActivity.kt` showed an empty `FlutterActivity` subclass:
    ```kotlin
    package com.nairitroy.optivus

    import io.flutter.embedding.android.FlutterActivity

    class MainActivity : FlutterActivity()
    ```
  - Inspection of `android/app/src/main/AndroidManifest.xml` (line 12) showed `android:launchMode="singleTop"`.
  - Android's `onNewIntent` callback is only executed when an Activity is running in background/foreground. When an app is launched from a **killed/terminated state**, intent extras are delivered to `onCreate()`, which `MainActivity.kt` does not currently intercept or expose to Flutter via a MethodChannel.
  - Inspection of `lib/core/router/app_router.dart` confirmed routing defaults to `/loading` without querying native initial launch intent payloads.

## 2. Logic Chain
- **Issue 61**:
  1. Platform channel invocations execute asynchronously across binary messengers (`MethodChannel`).
  2. On iOS (or test runners without native plugin registrations), missing or failing channels throw `MissingPluginException` or `PlatformException`.
  3. Because `main.dart` and native adapters currently lack an explicit `try-catch` catching `MissingPluginException` and `PlatformException`, unhandled platform errors bubble up to app bootstrap, breaking engine initialization or failing Riverpod state providers.
  4. Introducing `safePlatformCall<T>` in `lib/core/utils/platform_channel_boundary.dart` ensures all platform calls catch `MissingPluginException` and `PlatformException`, log diagnostics, and return a safe typed fallback without uncaught exceptions.

- **Issue 62**:
  1. Notification clicks on Android launch `MainActivity` with intent extras (payload, deep link URI).
  2. On cold start from killed app state, `onCreate()` receives the intent extras, while `onNewIntent()` is never called.
  3. Because `MainActivity.kt` does not store `intent.extras` in `onCreate()` or provide a MethodChannel (`getInitialNotificationPayload`), Flutter initializes without knowing the click payload.
  4. Adding intent caching in `MainActivity.kt` + a native MethodChannel `com.nairitroy.optivus/notification_intent` + `NotificationIntentService` in Dart enables Flutter to recover initial notification click payloads during cold start and route users directly to the targeted screen.

## 3. Caveats
- No caveats. Investigation was conducted directly against `lib/main.dart`, `lib/services/native/native_service_adapters.dart`, `lib/core/router/app_router.dart`, `android/app/src/main/kotlin/com/nairitroy/optivus/MainActivity.kt`, and `android/app/src/main/AndroidManifest.xml`.

## 4. Conclusion
- Root causes for both Group J Issues 61 & 62 are precisely identified.
- Comprehensive architectural designs for both fixes have been established without modifying any source code files (read-only compliance).
- Complete targeted and regression test specifications have been defined.

## 5. Verification Method
- **Targeted Unit Tests**:
  - `flutter test test/group_j_issue_61_ios_channel_safety_test.dart`
  - `flutter test test/group_j_issue_62_android_notification_intent_test.dart`
- **Regression Tests**:
  - `flutter test test/onboarding_routing_test.dart`
  - `flutter test test/group_i_issues_43_to_55_test.dart`
  - `flutter analyze`
- **Invalidation Conditions**:
  - Unhandled `MissingPluginException` or `PlatformException` thrown during iOS bootstrap.
  - Failure to recover notification intent payload on Android cold boot from killed state.

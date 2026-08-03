# Flutter and its plugins publish consumer rules. Keep only application entry
# points that are discovered by Android or Firebase at runtime.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations,AnnotationDefault

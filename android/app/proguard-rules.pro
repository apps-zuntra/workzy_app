# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Firebase ProGuard Rules
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-dontwarn javax.annotation.**

# Keep models and entities if serialized
-keepclassmembers class * {
    @com.google.firebase.database.IgnoreExtraProperties *;
    @com.google.firebase.firestore.IgnoreExtraProperties *;
    @com.google.firebase.firestore.PropertyName *;
}

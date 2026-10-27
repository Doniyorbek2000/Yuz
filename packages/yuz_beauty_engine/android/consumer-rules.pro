# MediaPipe Tasks uses JNI and reflection on its generated protobuf classes.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**

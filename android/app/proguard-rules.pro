# TFLite
-keep class org.tensorflow.** { *; }
-keep interface org.tensorflow.** { *; }
-keepclassmembers class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Ultralytics YOLO Plugin
-keep class com.ultralytics.** { *; }
-keep interface com.ultralytics.** { *; }
-keepclassmembers class com.ultralytics.** { *; }
-dontwarn com.ultralytics.**

# GPU Delegate
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
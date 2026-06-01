# Flutter / embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications (Dexterous) — receivers vía reflexión + Gson
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }

# sqlite3_flutter_libs / drift — librería nativa cargada por JNI
-keep class org.sqlite.** { *; }

# flutter_tts
-keep class com.tundralabs.fluttertts.** { *; }

# video_player (ExoPlayer/Media3)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Play Core (split install referenciado por Flutter, puede faltar)
-dontwarn com.google.android.play.core.**

# Genéricos seguros
-keepattributes SourceFile,LineNumberTable
-keep class * extends java.util.ListResourceBundle { protected java.lang.Object[][] getContents(); }

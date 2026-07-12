# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase (securite renforcee : ne garde que les membres publics pour
# limiter la surface de reverse engineering. Si une classe non-publique
# est utilisee par reflexion, ajouter une regle specifique.)
-keep class com.google.firebase.** { public *; }
-keep class com.google.android.gms.** { public *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Dio / OkHttp
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Encrypt
-keep class com.pointycastle.** { *; }
-dontwarn com.pointycastle.**

# Play Core (non utilisé, ignore les avertissements R8)
-dontwarn com.google.android.play.core.**

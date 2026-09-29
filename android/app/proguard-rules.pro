# ==============================================================
# MindSpaceNLP ProGuard/R8 Keep Rules
# ==============================================================
# R8 is enabled for release builds. These rules prevent stripping
# of classes that are accessed via reflection or JNI.
# ==============================================================

# --- Flutter Engine ---
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# --- Firebase Core ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- Firebase Messaging (FCM) ---
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- Google Sign-In ---
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# --- Flutter Local Notifications ---
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# --- AndroidX WorkManager (used by background_downloader) ---
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# --- AndroidX Core & AppCompat ---
-keep class androidx.core.** { *; }
-keep class androidx.appcompat.** { *; }
-dontwarn androidx.core.**
-dontwarn androidx.appcompat.**

# --- Video Player / ExoPlayer ---
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# --- WebView Flutter ---
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# --- Wakelock Plus ---
-keep class dev.fluttercommunity.plus.wakelock.** { *; }

# --- PDFx ---
-keep class io.scer.pdfx.** { *; }

# --- Gson / JSON serialization (transitive from Firebase/GMS) ---
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# --- General: keep enums (used in serialization) ---
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- General: keep Parcelable implementations ---
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# --- General: keep Serializable ---
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# --- General: keep native methods ---
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- Suppress common warnings from transitive deps ---
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-dontwarn kotlin.**
-dontwarn kotlinx.**

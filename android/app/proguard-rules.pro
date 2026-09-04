# Flutter's own engine classes are reached reflectively from native code, so
# R8 cannot see the references and would strip them.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage reaches AndroidX Security through reflection.
-keep class androidx.security.crypto.** { *; }

# Keep annotations R8 uses to decide what else is reachable.
-keepattributes *Annotation*

# Line numbers make a Play Console crash report readable; the source file name
# is renamed so it does not leak the original paths.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

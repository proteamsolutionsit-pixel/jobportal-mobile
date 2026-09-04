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

# Flutter's embedding references Play Core for deferred components — split
# installs, downloaded-on-demand feature modules. This app uses none of that and
# does not depend on Play Core, so the classes genuinely are not there and never
# will be reached; R8 sees the references and fails the build over them.
#
# -dontwarn, NOT -keep: keeping would demand classes that do not exist. This says
# the references are known-dangling and safe to drop.
#
# If deferred components are ever adopted, remove this and add the real
# com.google.android.play:core dependency instead.
-dontwarn com.google.android.play.core.**

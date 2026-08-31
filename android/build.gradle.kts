allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force every Flutter plugin to compile against the same SDK as :app.
//
// Setting compileSdk on :app alone is NOT enough. Each plugin carries its own,
// and the build failed on `:file_picker:checkReleaseAarMetadata` with
// ":file_picker is currently compiled against android-34" while
// flutter_plugin_android_lifecycle demanded 36. The plugin authors set 34; only
// the consuming project can raise it.
//
// compileSdk decides which APIs are AVAILABLE at compile time. It does not
// raise the minimum Android version anything runs on — that is minSdk, and it
// is untouched here.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            val setter = android.javaClass.methods.firstOrNull {
                it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType
            }
            setter?.invoke(android, 36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

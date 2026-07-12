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
    // Force compileSdk >= 34 pour tous les subprojects/plugins (ex: objectbox_flutter_libs)
    if (project.name != "app" && project.name != "gradle") {
        afterEvaluate {
            if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
                project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                    compileSdkVersion(36)
                    defaultConfig {
                        targetSdkVersion(36)
                    }
                }
            }
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

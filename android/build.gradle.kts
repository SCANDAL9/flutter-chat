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
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            configure<com.android.build.gradle.LibraryExtension> {
                if (namespace == null) {
                    namespace = if (project.group.toString().isNotEmpty() && project.group.toString() != "unspecified") {
                        project.group.toString()
                    } else {
                        "com.example.${project.name.replace("-", "_")}"
                    }
                }
                val currentSdk = compileSdk
                if (currentSdk == null || currentSdk < 34) {
                    compileSdk = 34
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

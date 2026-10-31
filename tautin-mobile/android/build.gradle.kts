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

// Some Flutter plugins ship a JVM target that differs from the app (e.g. Java 8
// sources with a newer Kotlin toolchain), which fails the build with
// "Inconsistent JVM-target compatibility". Force every module to the same
// target so the whole APK is consistent.
//
// This must run *after* every project is evaluated: the Android Gradle Plugin
// sets `JavaCompile.sourceCompatibility` from its own `compileOptions` during
// its own `afterEvaluate`, so configuring the tasks earlier gets overwritten.
val jvmTarget = JavaVersion.VERSION_17.toString()

gradle.projectsEvaluated {
    allprojects {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = jvmTarget
            targetCompatibility = jvmTarget
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions.jvmTarget = jvmTarget
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

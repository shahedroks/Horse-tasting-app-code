import org.gradle.api.JavaVersion
import org.gradle.api.Task
import org.gradle.api.tasks.compile.JavaCompile

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

// AGP 8+ requires `namespace` on every Android library. Older plugins (e.g. ar_flutter_plugin) omit it;
// derive it from AndroidManifest `package` when unset.
// Register before `evaluationDependsOn(":app")` so hooks exist when subprojects evaluate.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val currentNs = try {
            androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as? String
        } catch (_: Exception) {
            return@afterEvaluate
        }
        if (!currentNs.isNullOrBlank()) return@afterEvaluate

        val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) return@afterEvaluate
        val pkg =
            Regex("""package\s*=\s*"([^"]+)"""")
                .find(manifestFile.readText())
                ?.groupValues
                ?.get(1)
                ?: return@afterEvaluate
        try {
            androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, pkg)
        } catch (_: Exception) {
            // If setter is unavailable, the project will fail as before.
        }
    }
}

// Legacy plugins default Java 8 while Kotlin targets the host JDK; align with the app (Java 17).
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            try {
                val compileOptions =
                    androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                compileOptions.javaClass
                    .getMethod("setSourceCompatibility", JavaVersion::class.java)
                    .invoke(compileOptions, JavaVersion.VERSION_17)
                compileOptions.javaClass
                    .getMethod("setTargetCompatibility", JavaVersion::class.java)
                    .invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (_: Exception) {
                // Not an Android project or API mismatch
            }
        }
        tasks.withType(JavaCompile::class.java).configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        try {
            @Suppress("UNCHECKED_CAST")
            val kotlinCompileClass =
                Class.forName("org.jetbrains.kotlin.gradle.tasks.KotlinCompile") as Class<out Task>
            tasks.withType(kotlinCompileClass).configureEach {
                val kotlinOptions = javaClass.getMethod("getKotlinOptions").invoke(this)
                kotlinOptions.javaClass
                    .getMethod("setJvmTarget", String::class.java)
                    .invoke(kotlinOptions, JavaVersion.VERSION_17.toString())
            }
        } catch (_: ClassNotFoundException) {
            // Kotlin not used in this subproject
        } catch (_: Exception) {
            // Ignore if API differs
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

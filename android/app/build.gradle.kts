import java.util.Properties
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.zagorito.spots_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    tasks.withType<JavaCompile> {
        options.compilerArgs.add("-Xlint:-options")
    }

    defaultConfig {
        applicationId = "com.zagorito.spots_app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

val validateOfficialSpotCatalog by tasks.registering {
    group = "verification"
    description =
        "Refuse tout APK/AAB Android sans le catalogue officiel complet."

    doLast {
        val encodedDefines = providers.gradleProperty("dart-defines")
            .orNull
            .orEmpty()

        val encryptionKey = encodedDefines
            .split(',')
            .asSequence()
            .filter { it.isNotBlank() }
            .mapNotNull { encoded ->
                try {
                    String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
                } catch (_: IllegalArgumentException) {
                    null
                }
            }
            .firstOrNull { it.startsWith("CSV_ENCRYPTION_KEY=") }
            ?.substringAfter('=')
            .orEmpty()

        if (encryptionKey.isBlank()) {
            throw GradleException(
                "Build Android refuse : CSV_ENCRYPTION_KEY est absente. " +
                    "Utilisez tools/run_app.sh ou tools/build_release.sh."
            )
        }

        val keyBytes = try {
            Base64.getDecoder().decode(encryptionKey)
        } catch (_: IllegalArgumentException) {
            throw GradleException(
                "Build Android refuse : CSV_ENCRYPTION_KEY n'est pas un Base64 valide."
            )
        }
        if (keyBytes.size != 32) {
            throw GradleException(
                "Build Android refuse : CSV_ENCRYPTION_KEY doit contenir 32 octets."
            )
        }

        val catalogFile = rootProject.projectDir.parentFile
            .resolve("assets/spots.csv.enc")
        if (!catalogFile.isFile) {
            throw GradleException(
                "Build Android refuse : assets/spots.csv.enc est introuvable."
            )
        }

        val payload = catalogFile.readBytes()
        if (payload.size <= 16 || (payload.size - 16) % 16 != 0) {
            throw GradleException(
                "Build Android refuse : l'asset chiffre des spots est invalide."
            )
        }

        val plaintext = try {
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                SecretKeySpec(keyBytes, "AES"),
                IvParameterSpec(payload.copyOfRange(0, 16)),
            )
            cipher.doFinal(payload.copyOfRange(16, payload.size))
        } catch (_: Exception) {
            throw GradleException(
                "Build Android refuse : la cle Release ne correspond pas au " +
                    "catalogue officiel chiffre."
            )
        }

        val lines = plaintext.toString(Charsets.UTF_8).lineSequence()
        val header = lines.firstOrNull()?.trimEnd('\r')
        if (header?.split(',')?.take(3) !=
            listOf("Nom", "Latitude", "Longitude")
        ) {
            throw GradleException(
                "Build Android refuse : l'en-tete du catalogue officiel est invalide."
            )
        }

        val spotCount = plaintext
            .toString(Charsets.UTF_8)
            .lineSequence()
            .drop(1)
            .count { it.isNotBlank() }
        if (spotCount < 6000) {
            throw GradleException(
                "Build Android refuse : catalogue officiel incomplet " +
                    "($spotCount spots, minimum attendu : 6000)."
            )
        }

        logger.lifecycle(
            "Catalogue officiel valide : $spotCount spots chiffres verifies."
        )
    }
}

tasks.named("preBuild") {
    dependsOn(validateOfficialSpotCatalog)
}

// La configuration du compileSdk pour les plugins est centralisée dans android/build.gradle.kts

configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.13.1")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.browser:browser:1.7.0")
        // Google Mobile Ads 25.3.0 référence encore WorkManager 2.7.0.
        // Cette ancienne version échoue à instancier sa WorkDatabase après
        // minification R8/AGP 9. Utiliser la version AndroidX stable actuelle,
        // compatible avec minSdk 24 et compileSdk 36.
        force("androidx.work:work-runtime:2.11.2")
    }
}

import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

// The generated Room schema is committed so migrations are testable rather than a surprise.
ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

android {
    namespace = "ir.parsavisions.xirouter"
    compileSdk = 37

    defaultConfig {
        applicationId = "ir.parsavisions.xirouter"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // Release artifacts must never be produced unsigned. Keep debug usable on clean checkouts,
    // but fail configuration with an actionable message whenever a release task is requested.
    val keystoreFile = rootProject.file("keystore.properties")
    val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
    if (releaseRequested && !keystoreFile.exists()) {
        error("Release signing is missing: create ${keystoreFile.path} with storeFile, storePassword, keyAlias, and keyPassword.")
    }
    val keystoreProps = keystoreFile.takeIf { it.exists() }?.let {
        Properties().apply { it.inputStream().use(::load) }
    }
    if (releaseRequested && keystoreProps != null) {
        val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").filter { keystoreProps.getProperty(it).isNullOrBlank() }
        if (missing.isNotEmpty()) error("Release signing is incomplete in ${keystoreFile.path}: missing ${missing.joinToString()}.")
        val configuredStore = rootProject.file(keystoreProps.getProperty("storeFile"))
        if (!configuredStore.isFile) error("Release keystore does not exist: ${configuredStore.path}")
    }

    signingConfigs {
        if (keystoreProps != null) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Same key as release so a debug install upgrades the released app in place.
            if (keystoreProps != null) signingConfig = signingConfigs.getByName("release")
        }
        release {
            if (keystoreProps != null) signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    sourceSets.getByName("androidTest").assets.srcDir("$projectDir/schemas")
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring(libs.desugar.jdk.libs)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp)
    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.animation)
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.room.testing)
}

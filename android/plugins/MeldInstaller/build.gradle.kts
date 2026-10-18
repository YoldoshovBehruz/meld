plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.meld.installer"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.5.1.stable")
    implementation("androidx.core:core-ktx:1.13.1")
}
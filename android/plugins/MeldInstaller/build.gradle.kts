plugins {
    id("com.android.library") version "8.5.0"
}

android {
    namespace = "com.meld.installer"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    // Godot Android library подтягивается автоматически из окружения сборки
    compileOnly("org.godotengine:godot:4.5.0.stable")
}
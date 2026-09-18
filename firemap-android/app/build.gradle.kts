plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }

android {
    namespace = "pl.firemap.zastep"
    compileSdk = 36
    defaultConfig { applicationId = "pl.firemap.zastep"; minSdk = 26; targetSdk = 35; versionCode = 3; versionName = "1.1.0-pilot" }
    buildTypes { release { isMinifyEnabled = false } }
    buildFeatures { viewBinding = false }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
}

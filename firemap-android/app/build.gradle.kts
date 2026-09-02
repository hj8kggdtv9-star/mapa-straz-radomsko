plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }

android {
    namespace = "pl.firemap.zastep"
    compileSdk = 35
    defaultConfig { applicationId = "pl.firemap.zastep"; minSdk = 26; targetSdk = 35; versionCode = 2; versionName = "1.0.0-beta1" }
    buildTypes { release { isMinifyEnabled = false } }
    buildFeatures { viewBinding = false }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("com.google.android.gms:play-services-location:21.3.0")
}

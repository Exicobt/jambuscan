plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.deteksi_jambu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.deteksi_jambu"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // ── Nonaktifkan minify sementara untuk debug di Redmi ──
            // Aktifkan kembali setelah deteksi berhasil, dan pastikan
            // proguard-rules.pro sudah lengkap.
            isMinifyEnabled = false
            isShrinkResources = false

            signingConfig = signingConfigs.getByName("debug")

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        // Uncomment blok ini setelah yakin proguard tidak memotong kelas YOLO/TFLite:
        //
        // getByName("release") {
        //     isMinifyEnabled = true
        //     isShrinkResources = true
        //     signingConfig = signingConfigs.getByName("debug")
        //     proguardFiles(
        //         getDefaultProguardFile("proguard-android-optimize.txt"),
        //         "proguard-rules.pro"
        //     )
        // }
    }
}

flutter {
    source = "../.."
}
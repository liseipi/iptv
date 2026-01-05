# iptv

iptv live

## Getting Started

###打包流程:
在 pubspec.yaml 中确认版本号：
```
version: 1.0.0+1
```

###打包 APK:
运行以下命令生成 Release 模式的 APK：
```
flutter build apk --release
```

###验证 APK：
将生成的 APK 传输到 Android 设备上测试：
```
adb devices
adb install ../../build/app/outputs/flutter-apk/app-release.apk
```

如果构建出错或者需要清除缓存重建，清理项目并重新构建：
```
cd android
./gradlew clean

flutter clean
flutter pub get
flutter build apk --release

分包
flutter build apk --split-per-abi
生成的包
app-armeabi-v7a-release.apk（32 位，老电视用，体积小）
app-arm64-v8a-release.apk（64 位，强烈推荐给新电视，体积适中）
app-x86_64-release.apk（极少数用）
```

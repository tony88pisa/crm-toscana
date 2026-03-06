@echo off
set PATH=C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;C:\flutter\bin;C:\Program Files\Git\cmd;C:\Users\tony1\.jdks\openjdk-25.0.2\bin;C:\Users\tony1\AppData\Local\Android\Sdk\platform-tools
set JAVA_HOME=C:\Users\tony1\.jdks\openjdk-25.0.2
set ANDROID_HOME=C:\Users\tony1\AppData\Local\Android\Sdk
set ANDROID_SDK_ROOT=C:\Users\tony1\AppData\Local\Android\Sdk

echo === Cleaning Flutter ===
call flutter clean

echo === Building APK v15 AI Potenziata ===
call flutter build apk --release --build-number 15 --build-name 15

echo.
echo EXIT_CODE=%ERRORLEVEL%
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo SUCCESS v15!
    copy "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\tony1\Desktop\CRM_Toscana_v15.apk" /Y
    echo Copiato su Desktop come CRM_Toscana_v15.apk
) else (
    echo FAILED v15!
)

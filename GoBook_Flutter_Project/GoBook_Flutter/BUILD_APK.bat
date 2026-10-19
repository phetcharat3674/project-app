@echo off
setlocal
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found. Install Flutter SDK and add flutter\bin to PATH.
  pause
  exit /b 1
)
if not exist android (
  echo Creating Android project files...
  flutter create --platforms=android .
  if errorlevel 1 (
    pause
    exit /b 1
  )
)
flutter pub get
if errorlevel 1 (
  pause
  exit /b 1
)
flutter build apk --release
if errorlevel 1 (
  echo Build failed. Check the error above.
  pause
  exit /b 1
)
echo.
echo APK location: build\app\outputs\flutter-apk\app-release.apk
pause

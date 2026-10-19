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
echo Getting packages...
flutter pub get
if errorlevel 1 (
  pause
  exit /b 1
)
echo Starting GoBook...
flutter run
pause

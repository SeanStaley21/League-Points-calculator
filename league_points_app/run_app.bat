@echo off
rem Temporary dev launcher -- delete once the app ships as a packaged
rem `flutter build windows` .exe (see tasks.md Priority 1).
cd /d "%~dp0"
call flutter pub get
call flutter run -d windows
pause

@echo off
rem 게임 실행. 블록 수를 줄여서 시험하려면: run.bat --blocks=200
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -- %*

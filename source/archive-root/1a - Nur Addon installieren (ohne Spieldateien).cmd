@echo off
call "%~dp0Install.cmd" -NoUI %*
exit /b %errorlevel%

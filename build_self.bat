
@ECHO off

SET CPATH=%~dp0
@ECHO.PATH:%CPATH%
REM SET CURR_DIR=%CPATH%

REM @CD "%CPATH%"

IF "%~1"=="" (SET ARCH=64) ELSE (SET ARCH=%~1)
IF "%~2"=="" (SET B_MD=0) ELSE (SET B_MD=%~2)
IF "%~3"=="" (SET B_TYPE=Release) ELSE (SET B_TYPE=%~3)
IF "%~4"=="" (SET DIR_INSTALL=%CPATH%out) ELSE (SET DIR_INSTALL=%~4)
@ECHO."args:'%*'"

REM @ECHO. --env--OPENSSL_ROOT:%OPENSSL_ROOT_DIR%
REM @ECHO. --env--ZLIB_ROOT:%ZLIB_ROOT%
REM @ECHO. --env--ZLIB_STATIC:%ZLIB_USE_STATIC_LIBS%
REM @ECHO. --env--ZSTD_ROOT:%ZSTD_ROOT%

SET TOOLS_DIR=..\..\tools

SET build_dir=build_arch_%ARCH%
@ECHO."  build dir:'%build_dir%'"

IF EXIST "%CPATH%%build_dir%" (
  @ECHO.RMDIR '%CPATH%%build_dir%'"
  RMDIR /S /Q "%CPATH%%build_dir%"
)
@ECHO.MKDIR '%CPATH%%build_dir%'"
MKDIR "%CPATH%%build_dir%"

SET BIN_CMAKE=cmake -S . -B "%build_dir%"
if "%ARCH%" == "32" (
  SET BIN_CMAKE=%BIN_CMAKE% -A Win32
) else (
  SET BIN_CMAKE=%BIN_CMAKE% -A x64
)
if "%B_MD%" == "1" (
  SET BIN_CMAKE=%BIN_CMAKE% -DBUILD_LIB_MD=ON
) else (
  SET BIN_CMAKE=%BIN_CMAKE% -DBUILD_LIB_MD=OFF
)

SET BIN_CMAKE=%BIN_CMAKE% -DLIBSTPOOL_DO_INSTALL=ON -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=%B_TYPE% -DCMAKE_INSTALL_PREFIX=%DIR_INSTALL%
@ECHO.%BIN_CMAKE%
%BIN_CMAKE%
REM cmake -S . -B "%build_dir%" -DCMAKE_BUILD_TYPE=%B_TYPE% -DCMAKE_INSTALL_PREFIX=%DIR_INSTALL%
cmake --build "%build_dir%" --config %B_TYPE% --parallel 16
cmake --install "%build_dir%" --config %B_TYPE%

exit /b 1


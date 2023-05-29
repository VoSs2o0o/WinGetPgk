cd /D %~dp0
set /p ver=<ver.txt
rmdir tmp\ /S /Q
md tmp\wingetpkg-%ver%
xcopy data tmp\wingetpkg-%ver%\data\ /S /Y
xcopy examples tmp\wingetpkg-%ver%\examples\ /S /Y
xcopy files tmp\wingetpkg-%ver%\files\ /S /Y
xcopy lib tmp\wingetpkg-%ver%\lib\ /S /Y
xcopy manifests tmp\wingetpkg-%ver%\manifests\ /S /Y
xcopy tasks tmp\wingetpkg-%ver%\tasks\ /S /Y
xcopy templates tmp\wingetpkg-%ver%\templates\ /S /Y
xcopy CHANGELOG.md tmp\wingetpkg-%ver%\ /Y
xcopy hiera.yaml tmp\wingetpkg-%ver%\ /Y
xcopy LICENSE tmp\wingetpkg-%ver%\ /Y
xcopy metadata.json tmp\wingetpkg-%ver%\ /Y
xcopy README.md tmp\wingetpkg-%ver%\ /Y

cd tmp
"c:\Program Files (x86)\7-Zip\7z.exe" a -ttar wingetpkg.tar  wingetpkg-%ver%
"c:\Program Files (x86)\7-Zip\7z.exe" a wingetpkg.tar.gz wingetpkg.tar
cd ..
move /Y tmp\wingetpkg.tar.gz wingetpkg.tar.gz

pause
@ECHO off

FOR /F "tokens=1-3 usebackq" %%a IN (`REG QUERY "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled`) DO (
	IF "%%a" == "HiberbootEnabled" (
		IF "%%c" == "0x1" (
			echo HiberbootEnabled is enabled!
			echo Running: REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
			pause
			REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
			if ERRORLEVEL 1 (
				echo Failed, Press Return to try again with elevated permissions.
				pause
				powershell -Command Start-Process cmd -Verb runas -ArgumentList "/C","D:\fastbootoff.bat"
			)
			pause
		) ELSE (
			IF "%%c" == "0x0" (
				echo HiberbootEnabled seems to be off.
			) ELSE (
				echo WARNING: Unknkown value for HiberbootEnabled!: "%%c"
				pause
			)
		)
	)
)

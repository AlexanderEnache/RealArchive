REM  This script moves remote Inbound 850 EDI to local directory,
REM  Runs PHP to import data into vin database from each PO in those 850s,
REM  Then zips and (locally) archives the 850 files.
REM
REM  Next it will create outbound CSV files (multiple different types of outbound EDI) and then copies them to a remote destination
REM  Then zips said csv files and (locally) archives each type in it's own folder.
REM
REM  @update - FCS no longer requires EDI 810 (invoices), it has been disabled (Nov 5th).
REM
REM  Created: January 2018
REM  Last Modified: November 2019
REM
REM Things to keep in mind when modifying this code
REM  1. Use "CTRL + A" to select the entire document and ensure that there are no trailing white spaces at the end of each line
REM     These white spaces can be interpreted as part of the variable causing their outputs to become incorrect
REM  2. Try to avoid comments on the same line as code, again this can cause trailing white spaces at the end of each line.
REM     Leave comments on the line before the code you are talking about to avoid these issues.
REM  3. Add 'Pause' without the quotes at the bottom of the file for testing. This will cause the command prompt to 
REM     stay open once it is done. Giving you the ability to read the outcome.

REM ================================================================
REM Uncomment the next line for testing purposes. It will stop the cmd line from auto-closing when an error is thrown
REM if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )


setlocal enabledelayedexpansion

REM EDI 856 / 810 Variables
REM
REM SUPPLIER
REM
REM		Location							|	Supplier Code
REM	----------------------------------------+-----------------------------------
REM		Dearborn							|	GLNZA
REM		Kansas City							|	GLNZC
REM		Louisville (Kentucky Truck AP)		|	GLNZD
REM		Westlake							|	GLNZE
REM		Wayne								|	GLNZG
REM		Louisville (Louisville AP)			|	GLNZH
REM
REM :Notes:
REM		This code is 1-to-1 from Ford's Assembly Plant to our GFX Mod Center, meaning Louisville needs two.
REM		GLNZB is GFX Plant 02 - parts manufacturing. Thus not VINTracker and no EDI 850s.
REM		GFX Wayne was GLNZF at one point. But for whatever reason, they needed to replace it and use a new code.
REM
SET _SUPPLIER=GLNZA

REM EDI 214 Variables
REM
REM		Location		|	Compound Code	|	Yard Name Code		|	United Nations Location Code	|	SCAC Code (J1 Msgs)
REM	--------------------+-------------------+-----------------------+-----------------------------------+--------------------------------------
REM		Dearborn		|	ZP				|	"GFX (DRB)"			|	USDEO							|	AUPL
REM		Kansas City		|	Z2				|	"GFX (KC)"			|	USMKC							|	NMLA
REM		Louisville		|	ZQ				|	"GFX (KY)"			|	USLUI							|	COOJ
REM		Westlake		|	X2				|	"GFX (OH)"			|	WLX		(CONFIRM)				|	VOIT
REM		Wayne			|					|						|									|	
REM
REM :Notes:
REM		We currently do not know these values for GFX Wayne (UPDATE ON EVERY FORD FACILITY)
REM		Louisville will use the same values for both supplier codes.
REM
SET _COMPOUND=ZP
SET _YARDCODE="GFX (DRB)"
SET _UNLOCODE=USDEO
SET _SCACODE=AUPL

REM Directories
REM  %~dp0 will automatically get the location of this file
SET _DIR_Local=%~dp0

REM For Production
REM SET _DIR_Remote=\\gfx-vantage\EpicorData\EDI\
REM SET _DIR_RemoteEvision=\\gfx-evision\OutboundEDI\

REM For testing (Create dummy remote directory before using):
SET _DIR_Remote=%_DIR_Local%Remote\
SET _DIR_RemoteEvision=%_DIR_Local%Remote\evision\


REM Local and Remote directories
REM C:\xampp\htdocs\VinTracker\EDI_Processing\Remote\
SET _DIR_R_Incoming_850=%_DIR_Remote%Inbound\FORDFCS850\
SET _DIR_R_Outgoing_856=%_DIR_RemoteEvision%856Ford\
SET _DIR_R_Outgoing_214=%_DIR_RemoteEvision%214Ford\
REM SET _DIR_R_Outgoing_810=%_DIR_RemoteEvision%810Ford\

SET _DIR_L_Incoming_850=%_DIR_Local%Incoming_850\
SET _DIR_L_Outgoing_856=%_DIR_Local%Outgoing_856\
SET _DIR_L_Outgoing_214=%_DIR_Local%Outgoing_214\
REM SET _DIR_L_Outgoing_810=%_DIR_Local%Outgoing_810\

REM C:\xampp\htdocs\VinTracker\EDI_Processing\
REM PHP File Processors
SET _PHP_Proc_850=%_DIR_Local%850.php
SET _PHP_Proc_856=%_DIR_Local%856.php
SET _PHP_Proc_214=%_DIR_Local%214.php
REM SET _PHP_Proc_810=%_DIR_Local%810.php

REM C:\xampp\htdocs\VinTracker\EDI_Processing\Archive\
REM Archives
SET _DIR_Arch_850=%_DIR_Local%Archive\850\
SET _DIR_Arch_856=%_DIR_Local%Archive\856\
SET _DIR_Arch_214=%_DIR_Local%Archive\214\
REM SET _DIR_Arch_810=%_DIR_Local%Archive\810\

REM C:\xampp\htdocs\VinTracker\EDI_Processing\Archive\
REM ArchivesRAR
SET _DIR_Arch_850rar=%_DIR_Local%Archive\850rar\
SET _DIR_Arch_856rar=%_DIR_Local%Archive\856rar\
SET _DIR_Arch_214rar=%_DIR_Local%Archive\214rar\
REM SET _DIR_Arch_810rar=%_DIR_Local%Archive\810rar\

REM C:\xampp\htdocs\VinTracker\EDI_Processing\Logs\
REM Logs
SET _LOG_850=%_DIR_Local%Logs\850.log
SET _LOG_856=%_DIR_Local%Logs\856.log
SET _LOG_214=%_DIR_Local%Logs\214.log
REM SET _LOG_810=%_DIR_Local%Logs\810.log

REM Script to copy files to another location for processing,
REM then move them to a different folder for archiving.
SET _FileCopyThenMove=%_DIR_Local%AllFilesInFolderCopyThenMove.ps1

REM Date and Time
REM  The following dates are gathered by using the :~ operator
REM  The :~ operator gets the substring in the following format %variableName:~offset,length%
SET year=%date:~10,4%
SET month=%date:~4,2%
SET day=%date:~7,2%
SET _DoM=%day%
SET _currDate=%year%-%month%-%day%
SET hour=%time:~0,2%
if "%hour:~0,1%" == " " SET hour=0%hour:~1,1%		REM  Getting the hour and checking if it is between 0-9... if so it adds a zero before it. 9 -> 09
SET minute=%time:~3,2%
if "%minute:~0,1%" == " " SET minute=0%minute:~1,1%	REM  Getting the minute and checking if it is between 0-9... if so it adds a zero before it. 9 -> 09

REM File Name To Fill With 214 Maps
SET _condensedDateTimeMinute=%year%%month%%day%%hour%%minute%
SET _combined214FileName=214-%_SUPPLIER%-%_condensedDateTimeMinute%.csv

REM Archive Files
SET _ARC_850=%_DIR_Arch_850%Archive_MAP850_%_currDate%\
SET _ARC_856=%_DIR_Arch_856%Archive_MAP856_%_currDate%\
SET _ARC_214=%_DIR_Arch_214%Archive_MAP214_%_currDate%\
REM SET _ARC_810=%_DIR_Arch_810%Archive_MAP810_%_currDate%\

REM Archive Files RAR
SET _ARC_850rar=%_DIR_Arch_850rar%Archive_MAP850_%_currDate%
SET _ARC_856rar=%_DIR_Arch_856rar%Archive_MAP856_%_currDate%
SET _ARC_214rar=%_DIR_Arch_214rar%Archive_MAP214_%_currDate%
REM SET _ARC_810rar=%_DIR_Arch_810rar%Archive_MAP810_%_currDate%

REM setting the path to be able to access WinRar
SET path="C:\Program Files\WinRAR\";%path%

REM ================================================================

REM  Clean up / Archive Old Files and Logs!

REM  If today is the first day of the month and there is no .rar folder created, then create one and back up all of last months EDI Messages
REM  xcopy /s /Y copies all directories and subdirectories that aren't empty. xcopy is equivalent COPY + DELETE
REM   /Y Suppresses prompting to confirm you want to overwrite an existing destination file.

REM Then we compress the EDI Messages with rar a -r -df
REM  -r does the compression recursively
REM  -df deletes the original file after it has been compressed

IF  "%_DoM%" == "01" (
	IF NOT EXIST %_ARC_850rar%.rar (
			xcopy /s /Y %_LOG_850% %_DIR_Arch_850%
			rar a -r -df %_ARC_850rar% %_DIR_Arch_850%		
		IF errorlevel 0 ( echo "Log file for %_currDate%" > %_LOG_850%
		) else ( echo "Failed to archive 850 files." >> %_LOG_850% )
	)
	
	IF NOT EXIST %_ARC_856rar%.rar (
		xcopy /s /Y %_LOG_856% %_DIR_Arch_856%
		rar a -r -df %_ARC_856rar% %_DIR_Arch_856%
		IF errorlevel 0 ( echo "Log file for %_currDate%" > %_LOG_856%
		) else ( echo "Failed to archive 856 files." >> %_LOG_856%  )
	)

	IF NOT EXIST %_ARC_214rar%.rar (
			xcopy /s /Y %_LOG_214% %_DIR_Arch_214%
			rar a -r -df %_ARC_214rar% %_DIR_Arch_214%
		IF errorlevel 0 ( echo "Log file for %_currDate%" > %_LOG_214%
		) else ( echo %errorlevel% "Failed to archive 214 files." >> %_LOG_214%  )
	)

	REM IF NOT EXIST %_ARC_810rar%.rar (
			REM xcopy /s /Y %_LOG_810% %_DIR_Arch_810%
			REM rar a -r -df %_ARC_810rar% %_DIR_Arch_810%
		REM IF errorlevel 0 ( echo "Log file for %_currDate%" > %_LOG_810%
		REM ) else ( echo "Failed to archive 810 files." >> %_LOG_810%  )
	REM )
)


REM ================================================================

REM Process Incoming!

FOR %%F IN ( %_DIR_R_Incoming_850%* ) DO (
	findstr /M /R /I "~ST\*850.*%_SUPPLIER%"  %%F
	IF !errorlevel! EQU 0 (
		move /Y %%F %_DIR_L_Incoming_850%
		echo "%_condensedDateTimeMinute%: Moved EDI 850 file %%F From Remote to Local" >> %_LOG_850% ) 
)

C:\xampp\php\php.exe %_PHP_Proc_850% %_DIR_L_Incoming_850% >> %_LOG_850%	
FOR %%F IN ( %_DIR_L_Incoming_850%* ) DO (
	move %%F %_DIR_Arch_850%
	IF errorlevel 0 ( echo "%_condensedDateTimeMinute%: Imported and archived EDI 850 file %%F" >> %_LOG_850%
	) else ( echo "%_condensedDateTimeMinute%: Error: Failed to archive 850 file %%F" >> %_LOG_850% ) 
)

REM ================================================================


REM  Process Outgoing!

REM  Use database data to make outgoing files.
REM  856 = ASN, 810 = Invoice. PHP will decide what (whether)
REM  to make and move them to outbound and archive directories.
REM  Each php file takes one argument of where to put files.
REM  We write to local first and then copy over to avoid
REM  possible transcription errors from network problems.


REM Process EDI 856 Messages begins by calling the 856.php, which will create 856 EDI messages into a local directory. Logging the output to the 856 log file
REM For each EDI Message created inside of the local directory, we xcopy to the remote directory.
REM If the xcopy or move fail, we automatically break from the loop. This runs every 15 minutes, so it will be attempted again soon. 

C:\xampp\php\php.exe %_PHP_Proc_856% %_DIR_L_Outgoing_856% >> %_LOG_856%
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%_FileCopyThenMove%' '%_DIR_L_Outgoing_856%' '%_DIR_R_Outgoing_856%' '%_DIR_Arch_856%' '%_LOG_856%'"

REM :PROCINV

REM Process 810s (Invoices), to turn off comment out below
REM Disabled Nov 5th 2019

REM Process EDI 810 Messages begins by calling the 810.php, which will create 810 EDI messages into a local directory. Logging the output to the 810 log file
REM For each EDI Message created inside of the local directory, we xcopy to the remote directory.
REM If the xcopy or move fail, we automatically break from the loop. This runs every 15 minutes, so it will be attempted again soon. 

REM C:\xampp\php\php.exe %_PHP_Proc_810% %_DIR_L_Outgoing_810% >> %_LOG_810%
REM PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%_FileCopyThenMove%' '%_DIR_L_Outgoing_810%' '%_DIR_R_Outgoing_810%' '%_DIR_Arch_810%' '%_LOG_810%'"

:PROCGTN

REM Process 214s (GT Nexus), to turn off comment out below

REM Process EDI 214 Messages begins by calling the 214.php, which will create 214 EDI messages into a local directory. Logging the output to the 214 log file
REM For each EDI Message created inside of the local directory, we xcopy to the remote directory.
REM If the xcopy or move fail, we automatically break from the loop. This runs every 15 minutes, so it will be attempted again soon.

C:\xampp\php\php.exe %_PHP_Proc_214% %_DIR_L_Outgoing_214% %_COMPOUND% %_YARDCODE% %_UNLOCODE% %_SCACODE% >> %_LOG_214%
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%_FileCopyThenMove%' '%_dir_L_Outgoing_214%' '%_dir_R_Outgoing_214%' '%_DIR_Arch_214%' '%_LOG_214%'"

:EOF
REM  If you want to run this script and have the Command Prompt stay open, add 'Pause' to the next line.
REM PAUSE
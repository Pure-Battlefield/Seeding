#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile=C:\Users\Brad\Documents\Dev\PureBattlefield\working\temp\Battlefield4Seeder.exe
#AutoIt3Wrapper_UseUpx=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <Inet.au3>
#include <IE.au3>
#include <Misc.au3>
#include <File.au3>

If True Then ; Setup
	; Global Constants
	$Settingsini = "BF4SeederSettings.ini"
	$ProgName = "Battlefield4 Auto-Seeder"
	$LogFileName = "BF4SeederLog.log"
	$BFWindowName = "[REGEXPTITLE:^Battlefield 4.$]"
	$HangProtectionTimeLimit = 30 * 60 * 1000  ;30 minutes

	; Global Variables
	Global $ie
	Global $HangProtectionTimer

	; Config
	FileInstall("BF4SeederSettings.ini", ".\")

	; Required Config Settings
	$ServerAddress = GetSetting("ServerAddress", true)
	$MinimumPlayers = GetSetting("MinPlayers", true)
	$MaximumPlayers = GetSetting("MaxPlayers", true)
	$Username = GetSetting("Username", true)

	; Defaulted/Optional Config Settings
	$SleepWhenNotSeeding = GetSetting("SleepWhenNotSeeding", false, "", 1)
	$SleepWhenSeeding = GetSetting("SleepWhenSeeding", false, "", 1)
	$DisplayPlayerCount = GetSetting("DisplayPlayerCount", false, "", "true")
	$PlayerCountRetry = GetSetting("PlayerCountRetry", false, "", 5)
	$EnableLogging = GetSetting("EnableLogging", false, "", "false")
	$EnableGameHangProtection = GetSetting("EnableGameHangProtection", false, "", "true")
EndIf

If True Then ; Initialization
	CheckSingleton() ; Check there is only one instance
	_IEErrorHandlerRegister("MyIEError") ; Register Global IE Error Handler
	_IEErrorNotify(True) ; Notify IE Errors via the console
	opt("WinTitleMatchMode",4) ; Set the Window TitleMatchMode to use regular expressions

	CheckUsername($username) ; Check the Username at the start so the user knows right away if they're logged in correctly
EndIf


;~~~~~~~~~~~~~~~~~~~~~ Main ~~~~~~~~~~~~~~~~~~~~~~~~
LogAll("---------------------------")
LogAll("Battlefield4 Seeder started")
while 1
	$playerCount = AttemptGetPlayerCount($ServerAddress)

	if( not( WinExists($BFWindowName)) And ($playerCount < $MinimumPlayers)) Then
		LogAll("Player Count/Minimum Threshold: " & $playerCount & "/" & $MinimumPlayers)
		LogAll("Attempting to join server.")
		JoinServer($ServerAddress)
	EndIf

	if( WinExists($BFWindowName) And ($playerCount > $MaximumPlayers)) Then
		LogAll("Player Count/Maximum Threshold: " & $playerCount & "/" & $MaximumPlayers)
		LogAll("Attempting to KickSelf()")
	    KickSelf()
	EndIf

	if(WinExists($BFWindowName)) Then
		sleep($SleepWhenSeeding * 60 * 1000)
	Else
		sleep($SleepWhenNotSeeding * 60 * 1000)
	EndIf


WEnd

; Get Settings from the ini file
Func GetSetting($settingName, $required, $notFoundMessage = "", $default = "")
	$setting = IniRead($Settingsini, "All", $settingName, $default)
	if $setting == "" Then
		If $required == true Then
			If $notFoundMessage == "" Then $notFoundMessage = $settingName & " not found in .ini file. Exiting."
			MsgBox(1, $ProgName, $notFoundMessage)
			Exit
		EndIf
	EndIf
	return $setting
EndFunc

; Attempt to get the player count
Func AttemptGetPlayerCount($server_page)
	;LogAll("AttemptGetPlayerCount(" & $server_page & ")")
	$i = -1
	$player_count = -1
	Do
		if($i > -1 And $player_count == -1) Then
			$rt = MsgBox(1, $ProgName, "Could not parse player count. Server may be down. Retrying in 10 seconds." & @CRLF & "Attempts: " & $i + 1, 10)
			LogAll("Could not parse player count. Retrying...")
			if($rt == 2) Then
				LogAll("Retry manually cancelled. Exiting.")
				Exit
			EndIf
		EndIf
		$i += 1
		$player_count = GetPlayerCount($server_page)
	Until $i == $PlayerCountRetry OR $player_count <> -1

	if($player_count = -1) Then
		LogAll("Could not parse player count. Server may be down.")
		MsgBox(0, $Progname, "Could not parse player count. Server may be down.")
		Exit
	EndIf

	;LogAll("PlayerCount attempt successful: " & $player_count)
	return $player_count
EndFunc

; Parse the response for the player count
Func GetPlayerCount($server_page)
	;LogAll("GetPlayerCount(" & $server_page & ")")
	$response =  FetchPage($server_page)

	$slots_loc = StringInStr($response, '"slots":{')
	$slots = StringMid($response, $slots_loc)

	$2loc= StringInStr($slots, '"2"')
	$playercount_loc = $2loc+15
	$player_count = StringMid($slots, $playercount_loc, 2)

	if(not StringIsDigit($player_count)) Then $player_count = StringMid($slots, $playercount_loc, 1)
	if $DisplayPlayerCount == "true" Then TrayTip($ProgName,"Player count: "& $player_count , 10)

	if(not StringIsDigit($player_count)) Then
		$player_count = -1
	EndIf

	;LogAll("Player count: " & $player_count)
	return $player_count
EndFunc

; Checks that the expected user is logged in
Func CheckUsername($username)
	;LogAll("CheckUsername(" & $username & ")")
	$response = FetchPage("http://battlelog.battlefield.com/bf4/")

	$nameloc = StringInStr($response, 'class="username" href="/bf4/user/')
	$name_with_junk = StringMid($response, $nameloc+33, 70)
	$name_split = StringSplit($name_with_junk,"/", 2)

	If $name_split[0] <> $username Then
	  MsgBox(1,$ProgName, "Incorrect account. Please log in with the correct account and try again")

	  Exit
	EndIf
EndFunc

; Fetches a page in the background without loading an IE Window
Func FetchPage($server_page)
	;LogAll("FetchPage(" & $server_page & ")")
	$binaryResponse = InetRead($server_page, 1)

	If ($binaryResponse == "") Then
		LogAll("Couldn't fetch the requested page: " & $server_page)
	EndIf

	$response = BinaryToString($binaryResponse)
	;LogAll("Response: " & $response)
	return $response
EndFunc

; Triggers server join in Battlelog
Func JoinServer($server_page)
	LogAll("JoinServer(" & $server_page &")")
	$rc = MsgBox(1, $ProgName, "Auto-seeding in five seconds...", 5)
	if( $rc == 2) Then
		LogAll("Auto-seeding manually cancelled. Exiting.")
		MsgBox(0, $ProgName, "Closing script.")
		Exit
	EndIf

	$ie = _IECreate($server_page)
	if $ie == 0 Then LogAll("IE instance not created: " & $server_page)
	OnAutoItExitRegister("QuitIEInstance")
	$ie.document.parentwindow.execScript('document.getElementsByClassName("btn btn-primary btn-large large arrow")[0].click()')

	StartHangProtectionTimer() ; Always assume the window was created successfully for Hang Timer

	$bfWindow = WinWaitActive($BFWindowName, "",5*60)
	If $bfWindow == 0 Then
		If WinExists($BFWindowName) == 0 Then
			LogAll("Battlefield window does not exist. Something went wrong.")
		EndIf
	EndIf

	sleep(10000)
	Send("!{TAB}")
	sleep(10000)
	$ieQuit = _IEQuit($ie)
	if($ieQuit == 0) Then LogAll("IEQuit fail: " & @CRLF & @error)
	OnAutoItExitUnRegister("QuitIEInstance")

	WinSetState($bfWindow, "", @SW_MINIMIZE)
EndFunc

; Auto self-kicks when seeding is no longer necessary
Func KickSelf()
	LogAll("KickSelf()")
	$rc = MsgBox(1, $ProgName, "Server is filling up. Auto-kicking in ten seconds...",10)
	if( $rc == 2) Then
		LogAll("Manually prevented KickSelf()")
		Exit
	EndIf

	CloseWindow()
EndFunc

; Uses a timer to terminate BF periodically to ensure that if the game hangs, it won't be indefinitely
Func HangProtection()
	If $EnableGameHangProtection == "true" Then
		If TimerDiff($HangProtectionTimer) >= $HangProtectionTimeLimit Then
			LogAll("Hang protection invoked.")
			CloseWindow()
		EndIf
	EndIf
EndFunc

; Starts/Resets the HangProtectionTimer
Func StartHangProtectionTimer()
	If $EnableGameHangProtection == "true" Then
		$HangProtectionTimer = TimerInit()
	EndIf
EndFunc

; Attempts to gracefully close BF4 window, but if it fails, it will hard kill it
Func CloseWindow()
	LogAll("CloseWindow()")
	$winClose = WinClose($BFWindowName)
	If $winClose == 0 Then LogAll("Battlefield 4 window not found.")

	$winClosed = WinWaitClose($BFWindowName, "", 15)
	If $winClosed ==  1 Then
		LogAll($BFWindowName & " window closed succesfully.")
		Return
	EndIf

	LogAll("Window not closed gracefully. Attempting to kill it.")
	WinKill($BFWindowName)
EndFunc

; Callback for IEError
Func MyIEError()
	LogAll("MyIEError()")
	MsgBox(0,$ProgName,"Internet Explorer-related error. Are you logged in to Battlelog? Script closing...")
	exit
EndFunc

; Closes IE Instance
Func QuitIEInstance()
	LogAll("QuitIEInstance()")
	$ieQuit = _IEQuit($ie)
	if($ieQuit == 0) Then LogAll("IEQuit fail: " & @CRLF & @error)
EndFunc

; Check to make sure there is only 1 instance of the Seeder running
Func CheckSingleton()
	If _Singleton($ProgName, 1) = 0 Then
		MsgBox(0,$ProgName,$ProgName & " is already running.")
		Exit
	EndIf
EndFunc

; Log to all log outputs (console and file, if enabled)
Func LogAll($logMessage)
	ConsoleWrite($logMessage & @CRLF)
	LogToFile($logMessage)
EndFunc

; Logs to a file
Func LogToFile($logMessage)
	if $EnableLogging == "true" Then
		_FileWriteLog(".\" & $LogFileName, $logMessage)
	EndIf
EndFunc

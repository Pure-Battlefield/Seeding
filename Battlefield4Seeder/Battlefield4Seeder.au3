#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile=C:\Users\Brad\Documents\Dev\PureBattlefield\working\temp\Battlefield4Seeder.exe
#AutoIt3Wrapper_UseUpx=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <Inet.au3>
#include <IE.au3>
#include <Misc.au3>
#include <File.au3>

opt("WinTitleMatchMode",4)

If True Then ; Global Vars
	$Settingsini = "BF4SeederSettings.ini"
	$ProgName = "Battlefield4 Auto-Seeder"
	$LogFileName = "BF4SeederLog.log"
	$BFWindowName = "[REGEXPTITLE:^Battlefield 4.$]"
	$HangProtectionTimeLimit = 30 * 60 * 1000  ;30 minutes
	Global $ie
EndIf

CheckSingleton()

If True Then ; Initialization
	_IEErrorHandlerRegister("MyIEError")
	FileInstall("BF4SeederSettings.ini", ".\")
EndIf


If True Then ; Load settings/Set Defaults
	$ServerAddress=IniRead($Settingsini, "All", "ServerAddress", "")
	if $ServerAddress == "" Then
		MsgBox(1, $ProgName,"Invalid ServerAddress, exitting")
		Exit
	EndIf


	$MinimumPlayers=IniRead($Settingsini, "All", "MinPlayers", "")
	if $MinimumPlayers == "" Then
		MsgBox(1, $ProgName,"Invalid MinPlayers, exitting")
		Exit
	EndIf

	$MaximumPlayers=IniRead($Settingsini, "All", "MaxPlayers", "")
	if $MaximumPlayers == "" Then
		MsgBox(1, $ProgName,"Invalid MaxPlayers, exitting")
		Exit
	EndIf

	$SleepWhenNotSeeding=IniRead($Settingsini, "All", "SleepWhenNotSeeding", "")
	if $SleepWhenNotSeeding == "" Then
		MsgBox(1, $ProgName,"Invalid MaxPlayers, exitting")
		Exit
	EndIf

	$SleepWhenSeeding=IniRead($Settingsini, "All", "SleepWhenSeeding", "")
	if $SleepWhenSeeding == "" Then
		MsgBox(1, $ProgName,"Invalid MaxPlayers, exitting")
		Exit
	EndIf

	Global $DisplayPlayerCount=IniRead($Settingsini, "All", "DisplayPlayerCount", "")
	if $DisplayPlayerCount == "" Then
		IniWrite($Settingsini,"All","DisplayPlayerCount","true")
		$DisplayPlayerCount = "true"
	EndIf

	Global $Username = IniRead($Settingsini, "All", "Username", "")
	if $User == "" Then
		MsgBox(1, $ProgName, "Can't find username, exiting.")
		Exit
	EndIf

	Global $PlayerCountRetry=IniRead($Settingsini, "All", "PlayerCountRetry", "")
	if $PlayerCountRetry == "" Then
		IniWrite($Settingsini, "All", "PlayerCountRetry", "5")
		$PlayerCountRetry = 5
	EndIf

	Global $EnableLogging=IniRead($Settingsini, "All", "EnableLogging", "")
	if $EnableLogging == "" Then
		IniWrite($Settingsini, "All", "EnableLogging", "false")
		$EnableLogging = "false"
	EndIf

	Global $EnableGameHangProtection=IniRead($Settingsini, "All", "EnableGameHangProtection", "")
	if $EnableGameHangProtection == "" Then
		IniWrite($Settingsini, "All", "EnableGameHangProtection", "true")
		$EnableGameHangProtection = "true"
	EndIf
EndIf

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

LogAll("---------------------------")
LogAll("Battlefield4 Seeder started")

CheckUsername($username)

$hangProtectionTimer = TimerInit()
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

	If $EnableGameHangProtection == "true" Then
		If TimerDiff($hangProtectionTimer) >= $HangProtectionTimeLimit Then
			LogAll("Hang protection invoked.")
			CloseWindow()
		EndIf
	EndIf
WEnd

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

	$response = BinaryToString(BinaryResponse)
	;LogAll("Response: " & $response)
	return $response
EndFunc

Func JoinServer($server_page)
	LogAll("JoinServer(" & $server_page &")")
	$rc = MsgBox(1, $ProgName, "Auto-seeding in five seconds...", 5)
	if( $rc == 2) Then
		LogAll("Auto-seeding manually cancelled. Exiting.")
		Exit
	EndIf

	$ie = _IECreate($server_page)
	if $ie == 0 Then LogAll("IE instance not created: " & $server_page)
	OnAutoItExitRegister("QuitIEInstance")
	$ie.document.parentwindow.execScript('document.getElementsByClassName("btn btn-primary btn-large large arrow")[0].click()')

	WinWaitActive($BFWindowName, "",5*60)
	sleep(30000)

	Send("!{TAB}")
	$ieQuit = _IEQuit($ie)
	if($ieQuit == 0) Then LogAll("IEQuit fail: " & @CRLF & @error)

	OnAutoItExitUnRegister("QuitIEInstance")
EndFunc

Func KickSelf()
	LogAll("KickSelf()")
	$rc = MsgBox(1, $ProgName, "Server is filling up. Auto-kicking in ten seconds...",10)
	if( $rc == 2) Then
		LogAll("Manually prevented KickSelf()")
		Exit
	EndIf

	CloseWindow()
EndFunc

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

Func MyIEError()
	LogAll("MyIEError()")
	MsgBox(0,$ProgName,"Internet Explorer-related error. Are you logged in to Battlelog? Script closing...")
	exit
EndFunc

Func QuitIEInstance()
	LogAll("QuitIEInstance()")
	$ieQuit = _IEQuit($ie)
	if($ieQuit == 0) Then LogAll("IEQuit fail: " & @CRLF & @error)
EndFunc

Func CheckSingleton()
	If _Singleton($ProgName, 1) = 0 Then
		MsgBox(0,$ProgName,$ProgName & " is already running.")
		Exit
	EndIf
EndFunc

Func LogAll($logMessage)
	LogToConsole($logMessage)
	LogToFile($logMessage)
EndFunc

Func LogToConsole($logMessage)
	ConsoleWrite($logMessage & @CRLF)
EndFunc

Func LogToFile($logMessage)
	if $EnableLogging == "true" Then
		_FileWriteLog(".\" & $LogFileName, $logMessage)
	EndIf
EndFunc

#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile=C:\Users\Brad\Documents\Dev\PureBattlefield\working\temp\Battlefield4Seeder.exe
#AutoIt3Wrapper_UseUpx=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <Inet.au3>
#include <IE.au3>
#include <Misc.au3>
#include <File.au3>

opt("WinTitleMatchMode",4)
$Settingsini = "BF4SeederSettings.ini"
$ProgName = "Battlefield4 Auto-Seeder"
$LogFileName = "BF4SeederLog.log"
$BFWindowName = "[REGEXPTITLE:^Battlefield 4.$]"
$HangProtectionTimeLimit = 30 * 60 * 1000  ;30 minutes
Global $ie

If _Singleton($ProgName, 1) = 0 Then
	MsgBox(0,$ProgName,$ProgName & " is already running.")
	Exit
EndIf

_IEErrorHandlerRegister("MyIEError")

FileInstall("BF4SeederSettings.ini", ".\")

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


LogToFile("---------------------------")
LogToFile("Battlefield4 Seeder started")

$hangProtectionTimer = TimerInit()
while 1
	$playerCount = AttemptGetPlayerCount($ServerAddress)

	if( not( WinExists($BFWindowName)) And ($playerCount < $MinimumPlayers)) Then
		LogToFile("Player Count/Minimum Threshold: " & $playerCount & "/" & $MinimumPlayers)
		LogToFile("Attempting to join server.")
		JoinServer($ServerAddress)
	EndIf

	if( WinExists($BFWindowName) And ($playerCount > $MaximumPlayers)) Then
		LogToFile("Player Count/Maximum Threshold: " & $playerCount & "/" & $MaximumPlayers)
		LogToFile("Attempting to KickSelf()")
	    KickSelf()
	EndIf

	if(WinExists($BFWindowName)) Then
		sleep($SleepWhenSeeding * 60 * 1000)
	Else
		sleep($SleepWhenNotSeeding * 60 * 1000)
	EndIf

	If $EnableGameHangProtection == "true" Then
		If TimerDiff($hangProtectionTimer) >= $HangProtectionTimeLimit Then
			LogToFile("Hang protection invoked.")
			CloseWindow()
		EndIf
	EndIf
WEnd

Func AttemptGetPlayerCount($server_page)
	;LogToFile("AttemptGetPlayerCount(" & $server_page & ")")
	$i = -1
	$player_count = -1
	Do
		if($i > -1 And $player_count == -1) Then
			$rt = MsgBox(1, $ProgName, "Could not parse player count. Server may be down. Retrying in 10 seconds." & @CRLF & "Attempts: " & $i + 1, 10)
			LogToFile("Could not parse player count. Retrying...")
			if($rt == 2) Then
				LogToFile("Retry manually cancelled. Exiting.")
				Exit
			EndIf
		EndIf
		$i += 1
		$player_count = GetPlayerCount($server_page)
	Until $i == $PlayerCountRetry OR $player_count <> -1

	if($player_count = -1) Then
		LogToFile("Could not parse player count. Server may be down.")
		MsgBox(0, $Progname, "Could not parse player count. Server may be down.")
		Exit
	EndIf

	;LogToFile("PlayerCount attempt successful: " & $player_count)
	return $player_count
EndFunc

Func GetPlayerCount($server_page)
	;LogToFile("GetPlayerCount(" & $server_page & ")")
	; Use InetRead instead of creating an IE window instance
	$response =  BinaryToString(InetRead($server_page, 1))

	; ConsoleWrite($response)
	$slots_loc = StringInStr($response, '"slots":{')
	$slots = StringMid($response, $slots_loc)

	; ConsoleWrite(stringleft($slots,100))
	$2loc= StringInStr($slots, '"2"')
	$playercount_loc = $2loc+15
	$player_count = StringMid($slots, $playercount_loc, 2)

	if(not StringIsDigit($player_count)) Then $player_count = StringMid($slots, $playercount_loc, 1)
	ConsoleWrite("Player count: "& $player_count & @CRLF)
	if $DisplayPlayerCount == "true" Then TrayTip($ProgName,"Player count: "& $player_count , 10)

	if(not StringIsDigit($player_count)) Then
		$player_count = -1
	EndIf

	;LogToFile("Player count: " & $player_count)
	return $player_count
EndFunc

Func JoinServer($server_page)
	LogToFile("JoinServer(" & $server_page &")")
	$rc = MsgBox(1, $ProgName, "Auto-seeding in five seconds...", 5)
	if( $rc == 2) Then
		LogToFile("Auto-seeding manually cancelled. Exiting.")
		Exit
	EndIf

	$ie = _IECreate($server_page)
	if $ie == 0 Then LogToFile("IE instance not created: " & $server_page)
	OnAutoItExitRegister("QuitIEInstance")
	$ie.document.parentwindow.execScript('document.getElementsByClassName("btn btn-primary btn-large large arrow")[0].click()')

	WinWaitActive($BFWindowName, "",5*60)
	sleep(30000)

	Send("!{TAB}")
	$ieQuit = _IEQuit($ie)
	if($ieQuit == 0) Then LogToFile("IEQuit fail: " & @CRLF & @error)

	OnAutoItExitUnRegister("QuitIEInstance")
EndFunc

Func KickSelf()
	LogToFile("KickSelf()")
	$rc = MsgBox(1, $ProgName, "Server is filling up. Auto-kicking in ten seconds...",10)
	if( $rc == 2) Then
		LogToFile("Manually prevented KickSelf()")
		Exit
	EndIf

	CloseWindow()
EndFunc

Func CloseWindow()
	LogToFile("CloseWindow()")
	$winClose = WinClose($BFWindowName)
	If $winClose == 0 Then LogToFile("Battlefield 4 window not found.")

	$winClosed = WinWaitClose($BFWindowName, "", 15)
	If $winClosed ==  1 Then
		LogToFile($BFWindowName & " window closed succesfully.")
		Return
	EndIf

	LogToFile("Window not closed gracefully. Attempting to kill it.")
	WinKill($BFWindowName)
EndFunc

Func MyIEError()
	LogToFile("MyIEError()")
	MsgBox(0,$ProgName,"Internet Explorer-related error. Are you logged in to Battlelog? Script closing...")
	exit
EndFunc

Func QuitIEInstance()
	LogToFile("QuitIEInstance()")
	$ieQuit = _IEQuit($ie)
	if($ieQuit == 0) Then LogToFile("IEQuit fail: " & @CRLF & @error)
EndFunc

Func LogToFile($logMessage)
	if $EnableLogging == "true" Then
		_FileWriteLog(".\" & $LogFileName, $logMessage)
	EndIf
EndFunc

; BattlefieldSeeder.au3 v2.6
#include <Inet.au3>
#include <IE.au3>
#include <Misc.au3>
#include <File.au3>
#include "W7Sound.au3"

If True Then ; Setup
	; Global Constants
	$Settingsini = "BFSeederSettings.ini"
	$ProgName = "Battlefield Auto-Seeder"
	$LogFileName = "BFSeederLog.log"

	; Global Variables
	Global $ie = 0
	Global $HangProtectionTimer
	Global $HangProtectionEnabled

	; Game-Specific Settings
	$BFWindowName = ""
	$PlayerCountRegex = ""
	$BattlelogMainPage = ""
	$CheckUsernameRegex = ""
	$JoinServerJS = ""
	$BattlefieldGame = ""
	$Mutted = False

	; Config
	FileInstall("BFSeederSettings.ini", ".\")

	; Required Config Settings
	$ServerAddress = GetSetting("ServerAddress0", true)
	Global $ServerAddressTRY[] = [GetSetting("ServerAddress0", true), GetSetting("ServerAddress1", true), GetSetting("ServerAddress2", true)]
	$MinimumPlayers = GetSetting("MinPlayers0", true)
	Global $MinimumPlayersTRY[] = [GetSetting("MinPlayers0", true), GetSetting("MinPlayers1", true), GetSetting("MinPlayer2", true)]
	$MaximumPlayers = GetSetting("MaxPlayers0", true)
	Global $MaximumPlayersTRY[] = [GetSetting("MaxPlayers0", true), GetSetting("MaxPlayers1", true), GetSetting("MaxPlayers2", true)]
	$Username = GetSetting("Username", true)

	; Defaulted/Optional Config Settings
	$SleepWhenNotSeeding = GetSetting("SleepWhenNotSeeding", false, "", .2)
	$SleepWhenSeeding = GetSetting("SleepWhenSeeding", false, "", .2)
	$DisplayPlayerCount = GetSetting("DisplayPlayerCount", false, "", "true")
	$PlayerCountRetry = GetSetting("PlayerCountRetry", false, "", 3000)
	$EnableLogging = GetSetting("EnableLogging", false, "", "false")
	$EnableGameHangProtection = GetSetting("EnableGameHangProtection", false, "", "true")
	$HangProtectionTimeLimit = GetSetting("HangProtectionTimeLimit", false, "", 2)
	$MuteGame = GetSetting("AutoMuteGame", false, "", "false")
EndIf

If True Then ; Initialization
	CheckSingleton() ; Check there is only one instance
	;_IEErrorHandlerRegister("MyIEError") ; Register Global IE Error Handler
	_IEErrorNotify(True) ; Notify IE Errors via the console
	opt("WinTitleMatchMode",4) ; Set the Window TitleMatchMode to use regular expressions
	;CheckUsername($username) ; Check the Username at the start so the user knows right away if they're logged in correctly
	GameSpecificSetup() ; Setup settings specific to each game
	if($ie == 0) Then
		LogAll("IE instance doesn't exist. Trying again.")
		OpenIEInstance()
		sleep(8000)
	 EndIf
	 OnAutoItExitRegister ("UnmuteGame")
EndIf


;~~~~~~~~~~~~~~~~~~~~~ Main ~~~~~~~~~~~~~~~~~~~~~~~~
LogAll("---------------------------")
LogAll("Battlefield Seeder started")
while 1
	; Attempt to get the player count
	;	- this will retry until PlayerCountRetry is reached or it successfully gets the player count
	$playerCount = AttemptGetPlayerCount($ServerAddress)
	Global $playerCountTRY[] = [AttemptGetPlayerCount($ServerAddressTRY[0]), AttemptGetPlayerCount($ServerAddressTRY[1]), AttemptGetPlayerCount($ServerAddressTRY[2])]

	;      Find minimum player count. Once we have more Seeders.
	;Local $index = 1
	;Local $minimum = 100
	;For $n = 1 To 3 Step +1
	;   if ($playerCount[$n] < $minimum)
	;	  $minimum = $playerCount[$n]
	;	  $index = $n
	;  EndIf
    ; Next

	; Check if Server 1 has minimum, then 2, then 3. Seeder will join 1 if it is below threshold,
	;    then 2, then 3
	$index = 0
	For $n = 2 To 0 Step -1
	   if ($playerCountTRY[$n] < $MinimumPlayersTRY[$n]) Then
		  $index = $n
	   EndIf
    Next
    $ServerAddress = $ServerAddressTRY[$index]
	$playerCount = $playerCountTRY[$index]
	$MinimumPlayers = $MinimumPlayers TRY[$index]
	$MaximumPlayers = $MaximumPlayersTRY[$index]

	; If the BF window doesn't exist and playerCount is under the min, start seeding
	if( not( WinExists($BFWindowName)) And ($playerCount < $MinimumPlayers)) Then
		CheckUsername($Username)
		LogAll("Player Count/Minimum Threshold: " & $playerCount & "/" & $MinimumPlayers)
		LogAll("Attempting to join server.")
		JoinServer($ServerAddress)
	EndIf

	; If the BF window exists and playerCount is over the maximum, kick self
	if( WinExists($BFWindowName) And ($playerCount > $MaximumPlayers)) Then
		LogAll("Player Count/Maximum Threshold: " & $playerCount & "/" & $MaximumPlayers)
		LogAll("Attempting to KickSelf()")
	    KickSelf()
	EndIf

	; Perform Idle Avoidance before sleeping
	IdleAvoidance()

	; Sleep for a period without checking
	if(WinExists($BFWindowName)) Then
		LogAll("Seeding.  Sleeping for " & $SleepWhenSeeding & " minutes.")
		$Full = WinGetTitle ($BFWindowName)
		$HWnD = WinGetHandle ($Full)
		WinSetState($HWnD, "", @SW_MINIMIZE)
		sleep($SleepWhenSeeding * 60 * 1000)
	Else
		LogAll("Not seeding.  Sleeping for " & $SleepWhenNotSeeding & " minutes." & " Cant find window:" & $BFWindowName)
		sleep($SleepWhenNotSeeding * 60 * 1000)
	EndIf

	; If the game has been running for 30 mins, kill it so that it will restart
	HangProtection()
WEnd


; Setup specific settings for BF3/BF4
Func GameSpecificSetup()
	$ProgName = $ProgName & " - " & $BattlefieldGame
	SetGame()

	If($BattlefieldGame = "bf4") Then
		$BFWindowName = "Battlefield 4" ; not sure why the regex wasnt working. Didnt bother to figure out why.
		$PlayerCountRegex = '"slots".*?"2":{"current":(.*?),'
		$BattlelogMainPage = "http://battlelog.battlefield.com/bf4/"
		$CheckUsernameRegex = 'class="username"\W*href="/bf4/user/(.*?)/'
		$JoinServerJS = 'document.getElementsByClassName("btn btn-primary btn-large large arrow")[0].click()'
	ElseIf($BattlefieldGame = "bf3") Then
		$BFWindowName = "[REGEXPTITLE:^Battlefield 3.$]"
		$PlayerCountRegex = '<td id="server-info-players">(\d+) / \d+</td>'
		$BattlelogMainPage = "http://battlelog.battlefield.com/bf3/"
		$CheckUsernameRegex = 'class="username"\W*href="/bf3/user/(.*?)/'
		$JoinServerJS = 'document.getElementsByClassName("base-button-arrow-almost-gigantic legacy-server-browser-info-button")[0].click()'
	Else
		MsgBox(0, $ProgName, "Invalid BattlefieldGame setting. Must be either BF3 or BF4.")
		Exit
	EndIf
EndFunc

; Determines which game is running on the server
Func SetGame()
	If(StringInStr($ServerAddress, "bf4", 0) > 0) Then
		$BattlefieldGame = "bf4"
	ElseIf(StringInStr($ServerAddress, "bf3", 0) > 0) Then
		$BattlefieldGame = "bf3"
	Else
		MsgBox(0, $ProgName, "Could not determine while Battlefield game the server is running.")
		Exit
	EndIf
EndFunc

; Get Settings from the ini file
Func GetSetting($settingName, $required, $notFoundMessage = "", $default = "")
	$setting = IniRead($Settingsini, "All", $settingName, "")
	if $setting == "" Then
		IniWrite($Settingsini, "All", $settingName, $default)
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
		MsgBox(0, $ProgName, "Could not parse player count. Server may be down.")
		Exit
	EndIf

	;LogAll("PlayerCount attempt successful: " & $player_count)
	return $player_count
EndFunc

; Parse the response for the player count
Func GetPlayerCount($server_page)
	LogAll("GetPlayerCount(" & $server_page & ")")
	;$response =  FetchPage($server_page)
	$response = LoadInIE($server_page)
	$matches = StringRegExp($response, $PlayerCountRegex, 1)
	If @error == 1 Then
		LogAll("No player count found.")
		$player_count = -1
		return $player_count
	EndIf

	$player_count = $matches[0]

	if(not StringIsDigit($player_count)) Then
		LogAll("Invalid player count: " & $player_count)
	EndIf
	if $DisplayPlayerCount == "true" Then TrayTip($ProgName,"Player count: "& $player_count , 10)

	if(not StringIsDigit($player_count)) Then
		$player_count = -1
	EndIf

	;LogAll("Player count: " & $player_count)
	return Number($player_count)
EndFunc

; Checks that the expected user is logged in
Func CheckUsername($username)
	;LogAll("CheckUsername(" & $username & ")")
	$server_page = $BattlelogMainPage
	;$response = FetchPage($server_page)
	$response = LoadInIE($server_page)
	;LogToFile($response)
	$matches = StringRegExp($response, $CheckUsernameRegex, 1)

	If @error == 1 Then
		MsgBox(1, $ProgName, "Cannot find logged in user. Please log in and try again.")
		LogAll("No logged-in account found.")
		Exit
	EndIf

	$loggedInUser = $matches[0]
	LogAll("$loggedInUser: " & $loggedInUser)

	If $loggedInUser <> $username Then
		MsgBox(1,$ProgName, "Incorrect account. Please log in with the correct account and try again")
		LogAll("Incorrect account (Required/Actual): " & $username & "/" & $loggedInUser)
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

	$result = LoadInIE($server_page)
	if($result == 0) Then
		LogAll("Could not load server page: " & $server_page)
		Return
	EndIf
	$ie.document.parentwindow.execScript($JoinServerJS)

	StartHangProtectionTimer() ; Always assume the window was created successfully for Hang Timer

	;$bfWindow = WinWaitActive($BFWindowName, "",2*60) ; Wait up to 2 minutes for the window to load
	;If $bfWindow == 0 Then
	;	If WinExists($BFWindowName) == 0 Then
	;		; This will happen if the account does not have required DLC
	;		LogAll("Battlefield window does not exist. Something went wrong.")
	;	EndIf
	;EndIf

	sleep(10000)
	Send("!{TAB}")
	sleep(10000)
	MuteGame()

	;WinSetState($bfWindow, "", @SW_MINIMIZE)
EndFunc

; Auto self-kicks when seeding is no longer necessary
Func KickSelf()
	LogAll("KickSelf()")
	$rc = MsgBox(1, $ProgName, "Server is filling up. Auto-kicking in ten seconds...",10)
	if( $rc == 2) Then
		LogAll("Manually prevented KickSelf()")
		Exit
	EndIf

	CloseWindow("Server filling up so kicked seeder.")
EndFunc

; Uses a timer to terminate BF periodically to ensure that if the game hangs, it won't be indefinitely
Func HangProtection()
	If $HangProtectionEnabled == True Then
		$HangProtectionTimeLimitInHours = $HangProtectionTimeLimit * 60 * 60 * 1000
		If TimerDiff($HangProtectionTimer) >= $HangProtectionTimeLimitInHours Then
			CloseWindow("Hang protection invoked.")
			StopHangProtectionTimer() ; Turn Hang protection off
		EndIf
	EndIf
EndFunc

; Starts/Resets the HangProtectionTimer
Func StartHangProtectionTimer()
	If $EnableGameHangProtection == "true" Then
		$HangProtectionEnabled = True
		$HangProtectionTimer = TimerInit()
	EndIf
EndFunc

; Stops the HangProtectionTimer
Func StopHangProtectionTimer()
	$HangProtectionEnabled = False
EndFunc

; Clicks in the top left of the window to reset the idle timer
Func IdleAvoidance()
	LogAll("IdleAvoidance()")
	if(not(WinExists($BFWindowName))) Then Return

	LogAll("BF Window exists. Attempting idle avoidance.")

	$Full = WinGetTitle ($BFWindowName) ; Get The Full Title..
	$HWnD = WinGetHandle ($Full) ; Get The Handle
	$iButton = 'Left' ; Button The Mouse Will Click I.E. "Left Or Right"
	$iClicks = '1' ; The Number Of Times To Click
	$iX = '0' ; The "X" Pos For The Mouse To Click
	$iY = '0' ; The "Y" Pos For The Mouse To Click
	If IsHWnD ($HWnD) And WinExists ($Full) <> '0' Then ; Win Check
		ControlClick ($HWnD, '','', $iButton, $iClicks, $iX, $iY) ; Clicking The Window While Its Minmized
	EndIf
EndFunc


; Attempts to gracefully close BF window, but if it fails, it will hard kill it
Func CloseWindow($reason)
	LogAll("CloseWindow()")
	$winClose = WinClose($BFWindowName)
	If $winClose == 0 Then
		LogAll("Battlefield window not found so can't close.")
		Return
	EndIf

	$winClosed = WinWaitClose($BFWindowName, "", 15)
	If $winClosed ==  1 Then
		MsgBox(0, $ProgName, "Battlefield closed intentionally." & @CRLF & "Reason: " & $reason, 10)
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

	; Important: the error object variable MUST be named $oIEErrorHandler
    Local $ErrorScriptline = $oIEErrorHandler.scriptline
    Local $ErrorNumber = $oIEErrorHandler.number
    Local $ErrorNumberHex = Hex($oIEErrorHandler.number, 8)
    Local $ErrorDescription = StringStripWS($oIEErrorHandler.description, 2)
    Local $ErrorWinDescription = StringStripWS($oIEErrorHandler.WinDescription, 2)
    Local $ErrorSource = $oIEErrorHandler.Source
    Local $ErrorHelpFile = $oIEErrorHandler.HelpFile
    Local $ErrorHelpContext = $oIEErrorHandler.HelpContext
    Local $ErrorLastDllError = $oIEErrorHandler.LastDllError
    Local $ErrorOutput = ""
    $ErrorOutput &= "--> COM Error Encountered in " & @ScriptName & @CR
    $ErrorOutput &= "----> $ErrorScriptline = " & $ErrorScriptline & @CR
    $ErrorOutput &= "----> $ErrorNumberHex = " & $ErrorNumberHex & @CR
    $ErrorOutput &= "----> $ErrorNumber = " & $ErrorNumber & @CR
    $ErrorOutput &= "----> $ErrorWinDescription = " & $ErrorWinDescription & @CR
    $ErrorOutput &= "----> $ErrorDescription = " & $ErrorDescription & @CR
    $ErrorOutput &= "----> $ErrorSource = " & $ErrorSource & @CR
    $ErrorOutput &= "----> $ErrorHelpFile = " & $ErrorHelpFile & @CR
    $ErrorOutput &= "----> $ErrorHelpContext = " & $ErrorHelpContext & @CR
    $ErrorOutput &= "----> $ErrorLastDllError = " & $ErrorLastDllError
    LogAll($ErrorOutput)
    ;SetError(1)
    ;Return

	exit
EndFunc

; Opens a global IE instance
Func OpenIEInstance($attemptCount = 0)
	LogAll("OpenIEInstance(), attempts: " & $attemptCount)
	$ie = _IECreate("about:blank", 0, 0)
	if($ie == 0) Then
		If($attemptCount > 4) Then
			LogAll("Cannot create IE Instance. Script closing...")
			MsgBox(0, $ProgName, "Cannot open IE. Script closing...")
			Exit
		EndIf

		LogAll("IE instance doesn't exist. Trying again.")
		sleep(5000)
		OpenIEInstance($attemptCount + 1)
		Return
	EndIf
	OnAutoItExitRegister("QuitIEInstance")
EndFunc

; Fetches a page in IE
Func LoadInIE($server_page)
	LogAll("Fetch a page using IE")
	if($ie == 0) Then
		LogAll("IE instance doesn't exist. Trying again.")
		OpenIEInstance()
		sleep(5000)
		LoadInIE($server_page)
		Return
	EndIf
	_IENavigate($ie, $server_page)
	LogAll("Navigated to " & $server_page)
	Return _IEBodyReadHTML($ie)
EndFunc

; Closes IE Instance
Func QuitIEInstance()
	LogAll("QuitIEInstance()")
	$ieQuit = _IEQuit($ie)
	if($ieQuit == 0) Then LogAll("IEQuit fail: " & @CRLF & @error)
	OnAutoItExitUnRegister("QuitIEInstance")
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

 ; Mute Game if option set
Func MuteGame()
   If (WinExists($BFWindowName) And $MuteGame == "true") Then
	  $Full = WinGetTitle ($BFWindowName)
	  $HWnD = WinGetHandle ($Full)
	  _MuteVolume("Battlefield 4�")
	  $Mutted = True
	  LogAll("Mutted")
   EndIf
EndFunc

 ; Unmute Game if it was mutted
Func UnmuteGame()
   if ($Mutted) Then
      $Full = WinGetTitle ($BFWindowName)
	  $HWnD = WinGetHandle ($Full)
	  _MuteVolume("Battlefield 4�")
	  LogAll("Unmutted")
   EndIf
EndFunc



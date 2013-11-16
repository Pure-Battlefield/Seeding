#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile=C:\Users\Brad\Documents\Dev\PureBattlefield\working\temp\Battlefield4Seeder.exe
#AutoIt3Wrapper_UseUpx=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <Inet.au3>
#include <IE.au3>
#include <Misc.au3>

opt("WinTitleMatchMode",2)
$Settingsini = "BF4SeederSettings.ini"
$ProgName = "Battlefield4 Auto-Seeder"
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

while 1

   if( not( WinExists("Battlefield 4?")) And (GetPlayerCount($ServerAddress) < $MinimumPlayers)) Then
	     JoinServer($ServerAddress)
	  EndIf

   if( WinExists("Battlefield 4?") And (GetPlayerCount($ServerAddress) >$MaximumPlayers)) Then
	     KickSelf()
	  EndIf

   if(WinExists("Battlefield 4?")) Then
	  sleep($SleepWhenSeeding * 60 * 1000)
   Else
	  sleep($SleepWhenNotSeeding * 60 * 1000)
   EndIf

WEnd



Func GetPlayerCount($server_page)

   ;$ie = _IECreate($server_page, 0, 0)
   ;OnAutoItExitRegister("QuitIEInstance")
   ;$response = _IEBodyReadHTML($ie)
   ;_IEQuit($ie)
   ;OnAutoItExitUnRegister("QuitIEInstance")
   ;$binaryResponse = InetRead($server_page, 1)
   ;$nBytesRead = @extended
   $response =  BinaryToString(InetRead($server_page, 1))
   ;MsgBox(0, $ProgName, "Bytes Read: " & $nBytesRead)
   MsgBox(0,$ProgName, $response)

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
	  MsgBox(0,$ProgName, "Could not parse player count. Server may be down.")
	  Exit
   EndIf


   return $player_count
EndFunc




Func JoinServer($server_page)
   $rc = MsgBox(1, $ProgName, "Auto-seeding in five seconds...", 5)
   if( $rc == 2) Then Exit

   $ie = _IECreate($server_page)
   OnAutoItExitRegister("QuitIEInstance")
   $ie.document.parentwindow.execScript('document.getElementsByClassName("btn btn-primary btn-large large arrow")[0].click()')


   WinWaitActive("Battlefield 4?", "",5*60)
   sleep(10000)
   Send("!{TAB}")
      _IEQuit($ie)
   OnAutoItExitUnRegister("QuitIEInstance")

EndFunc


Func KickSelf()
   $rc = MsgBox(1, $ProgName, "Server is filling up. Auto-kicking in ten seconds...",10)
   if( $rc == 2) Then Exit

   WinClose("Battlefield 4?")

EndFunc

Func MyIEError()
   MsgBox(0,$ProgName,"Internet Explorer-related error. Are you logged in to Battlelog? Script closing...")
   exit
EndFunc

Func QuitIEInstance()
      _IEQuit($ie)
EndFunc

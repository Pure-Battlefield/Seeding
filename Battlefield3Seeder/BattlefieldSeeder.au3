#include <Inet.au3>
#include <IE.au3>

opt("WinTitleMatchMode",2)

_IEErrorHandlerRegister("MyIEError")

$Settingsini = "BFSeederSettings.ini"
$ProgName = "Battlefield Auto-Seeder"

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


IniWrite("BFSeederSettings.ini","All", "ServerAddress","http://bf3-server1.purebattlefield.org/")

while 1
   
   if( not( WinExists("Battlefield 3™")) And (GetPlayerCount($ServerAddress) < $MinimumPlayers)) Then
	     JoinServer($ServerAddress)
	  EndIf
	  
   if( WinExists("Battlefield 3™") And (GetPlayerCount($ServerAddress) >$MaximumPlayers)) Then
	     KickSelf()
	  EndIf	  
	  
   if(WinExists("Battlefield 3™")) Then
	  sleep($SleepWhenSeeding * 60 * 1000)
   Else
	  sleep($SleepWhenNotSeeding * 60 * 1000)
   EndIf
   
WEnd



Func GetPlayerCount($server_page)
   $ie = _IECreate($server_page, 0, 0)

   $response = _IEBodyReadHTML($ie)
   $playercount_loc = StringInStr($response, '"server-info-players">')
   $player_count = StringMid($response, $playercount_loc+22, 2)
   
   if(not StringIsDigit($player_count)) Then $player_count = StringMid($response, $playercount_loc+22, 1)
   ConsoleWrite("Player count: "& $player_count & @CRLF)
   
   _IEQuit($ie)
   return $player_count
EndFunc


Func JoinServer($server_page)
   $rc = MsgBox(1, $ProgName, "Auto-seeding in five seconds...", 5)
   if( $rc == 2) Then Exit 
	  
   $ie = _IECreate($server_page)
   $ie.document.parentwindow.execScript('document.getElementsByClassName("base-button-arrow-almost-gigantic legacy-server-browser-info-button")[0].click()')
   
   WinWaitActive("Battlefield 3™", "",5*60)
   sleep(10000)
  ; ConsoleWrite("Minimizing" & @CRLF)
   ;WinSetState("Battlefield 3™", "", @SW_MINIMIZE)
   Send("!{TAB}")
   _IEQuit($ie)
EndFunc


Func KickSelf()
   $rc = MsgBox(1, $ProgName, "Server is filling up. Auto-kicking in ten seconds...",10)
   if( $rc == 2) Then Exit 
	  
   WinClose("Battlefield 3™")
   
EndFunc
   
Func MyIEError()
   MsgBox(0,$ProgName,"Internet Explorer-related error. Are you logged in to Battlelog? Script closing...")
   exit
EndFunc
   
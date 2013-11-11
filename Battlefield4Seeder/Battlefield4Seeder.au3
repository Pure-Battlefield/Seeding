#include <Inet.au3>
#include <IE.au3>
#include <Misc.au3>

opt("WinTitleMatchMode",2)
$Settingsini = "BF4SeederSettings.ini"
$ProgName = "Battlefield Auto-Seeder"
Global $G_ie

If _Singleton($ProgName, 1) = 0 Then
   MsgBox(0,$ProgName,$ProgName & " is already running.")
   Exit
EndIf

_IEErrorHandlerRegister("MyIEError")
_IEErrorNotify(True)

if True Then ;READ SETTINGS - This is just so I can compress the setting section
   FileInstall("BF4SeederSettings.ini", ".\")

   $ServerAddress=IniRead($Settingsini, "All", "ServerAddress", "")
   if $ServerAddress == "" Then 
	  MsgBox(1, $ProgName,"Invalid ServerAddress setting.") 
	  Exit 
   EndIf

   $MinimumPlayers=IniRead($Settingsini, "All", "MinPlayers", "")
   if $MinimumPlayers == "" Then 
	  MsgBox(1, $ProgName,"Invalid MinPlayers setting.") 
	  Exit 
   EndIf

   $MaximumPlayers=IniRead($Settingsini, "All", "MaxPlayers", "")
   if $MaximumPlayers == "" Then 
	  MsgBox(1, $ProgName,"Invalid MaxPlayers setting.") 
	  Exit 
   EndIf
   
   $Game=IniRead($Settingsini, "All", "Game", "BF4")
   If $Game == "BF4" Then
	  $GameName = "Battlefield 4™"
   ElseIf $Game == "BF3" Then
	  $GameName = "Battlefield 3™"
   Else
	  MsgBox(1, $ProgName,"Invalid Game setting. Possible values are BF4 and BF3.") 
	  Exit 
   EndIf
   


   $SleepWhenNotSeeding=IniRead($Settingsini, "All", "SleepWhenNotSeeding", 1)
   $SleepWhenSeeding=IniRead($Settingsini, "All", "SleepWhenSeeding", 1)
   Global $DisplayPlayerCount=IniRead($Settingsini, "All", "DisplayPlayerCount", "true")
   $Username=IniRead($Settingsini, "All", "Username", "")

EndIf


;~~~~~~~~~~~~~~~~~~~~~~~~Main Loop~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
while 1
   $G_ie = OpenIE()

   if( Not WinExists($GameName)) Then
	  
	  If $Username <> "" Then
		 CheckUserName($Username)
	  Else
		 CheckLoggedIn()
	  EndIf
	  
	  If( (GetPlayerCount($ServerAddress) < $MinimumPlayers) And (@error = 0) ) Then
		 JoinServer($ServerAddress)
	  EndIf	  
   Else
	  If (GetPlayerCount($ServerAddress) > $MaximumPlayers ) Then
		 KickSelf()
	  EndIf
   EndIf	  
	  
   CloseIE()
	  
   if( WinExists($GameName)) Then
	  sleep($SleepWhenSeeding * 60 * 1000)
   Else
	  sleep($SleepWhenNotSeeding * 60 * 1000)
   EndIf
   
WEnd

Func OpenIE()
   $G_ie = _IECreate("about:blank", 0, 0)
   OnAutoItExitRegister("QuitIEInstance")
   return $G_ie
EndFunc

Func CloseIE()
   OnAutoItExitUnRegister("QuitIEInstance")
   _IEQuit($G_ie)
EndFunc


Func CheckUsername($username)
   _IENavigate($G_ie, "http://battlelog.battlefield.com/bf4/")
   $response = _IEBodyReadHTML($G_ie)
   
   $nameloc = StringInStr($response, 'class="username" href="/bf4/user/')
   $name_with_junk = StringMid($response, $nameloc+33, 70)
   $name_split = StringSplit($name_with_junk,"/", 2)
   
   If $name_split[0] <> $username Then
	  $G_ie.visible= "True"
	  OnAutoItExitUnRegister("QuitIEInstance")
	  MsgBox(1,$ProgName, "Incorrect account. Please log in with the correct account and try again")
	  Exit
   EndIf
   
EndFunc

Func CheckLoggedIn()   
   _IENavigate($G_ie, "http://battlelog.battlefield.com/bf4/")
   $response = _IEBodyReadHTML($G_ie)
   
   ConsoleWrite($response)
EndFunc


Func GetPlayerCount($server_page)
   
   _IENavigate($G_ie, $ServerAddress)
   $response = _IEBodyReadHTML($G_ie)
   ;ConsoleWrite($response)
   $slots_loc = StringInStr($response, '"slots":{')
   $slots = StringMid($response, $slots_loc)
   
  ; ConsoleWrite(stringleft($slots,100))
   $2loc= StringInStr($slots, '"2":')
   $playercount_loc = $2loc+15
   $player_count = StringMid($slots, $playercount_loc, 2)
 ;  ConsoleWrite(stringleft($slots,100) & @CRLF)

   if(not StringIsInt($player_count)) Then 
	  $player_count = StringMid($slots, $playercount_loc, 1)
   EndIf
	  
   if(not StringIsInt($player_count)) Then 
	  TrayTip($ProgName,"Cannot load server page",10)
	  SetError(1)
	  return -1
   EndIf
	  
   ConsoleWrite("Player count: "& $player_count & @CRLF)
   if $DisplayPlayerCount == "true" Then TrayTip($ProgName,"Player count: "& $player_count , 10) 
   
   return Int($player_count)
EndFunc


Func JoinServer($server_page)
   ConsoleWrite("Joining " &@CRLF)

   $rc = MsgBox(1, $ProgName, "Auto-seeding in five seconds...", 5)
   if( $rc == 2) Then
	  MsgBox(0,$ProgName, "Closing script.")
	  Exit 
   EndIf
	  
   _IENavigate($G_ie, $ServerAddress)
   $G_ie.visible= "True"
   $G_ie.document.parentwindow.execScript('document.getElementsByClassName("btn btn-primary btn-large large arrow")[0].click()')
   WinWaitActive($GameName, "",5*60)
   sleep(10000)
   Send("!{TAB}")
   sleep(10000)
   WinSetState($GameName, "",@SW_MINIMIZE)
   $G_ie.visible= "False"

EndFunc

Func KickSelf()
   $rc = MsgBox(1, $ProgName, "Server is filling up. Auto-kicking in ten seconds...",10)
   if( $rc == 2) Then Exit 
	  
   WinClose($GameName)
   
EndFunc
   
Func MyIEError()
   MsgBox(0,$ProgName,"Internet Explorer-related error. Try running the script as an admin. (You'll have to log in to battlelog the first time you run the script)")
   exit
EndFunc

Func QuitIEInstance()
      _IEQuit($G_ie)
EndFunc
   
   
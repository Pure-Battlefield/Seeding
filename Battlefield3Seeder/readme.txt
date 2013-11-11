Coded by Tim Froehlich (Avatar2453, Avatar_Ko, Advacar, etc)

Goal: This script was made to automate seeding of Battlefield Servers. It will:

Join a server automatically if there are less than the minimum number of players in the server (default 36)
After joining, will minimize the game so that it takes less resources
Leave the server automatically if there are more than the maximum number of players in the server (default 64)
Prompt you whether you want to launch or leave the game before it does so, and do it anyways if you don't respond in time (5 and 10 seconds respectively)

Pre-requisites: Internet Explorer, Being logged into Battlelog and Origin.

How to run:
Just run BattlefieldSeeder.exe

How to change settings:
Open BFSeederSettings.ini in notepad, modify the Settings as you want, save, and restart BattlefieldSeeder.exe.

How to stop the script:
There will be an entry in your system tray with the same logo as the script. Right click it and click Exit

What are "SleepWhen[Not]Seeding" in the settings?
These specify how often (in minutes) to open up internet explorer and check the player count of the server. Checking the player count occurs in the background but you will see your PC momentarily slow down when it opens IE.
SleepWhenSeeding is active when BF3 is open, SleepWhenNotSeeding is active when BF3 is not open.
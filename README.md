# Site 19 Gun System Replica V2

# NOTE I WILL NO LONGER BE PROVIDING .RBXL FILES PLEASE GO HERE FOR RELEASES THE PLACE IS UNCOPYLOCKED IT IS JUST EASY PLEASE JUST DO IT: https://www.roblox.com/games/95481417748754/new-gun-system-test

# A complete and total rewrite from last time!

# This gun system was made to replicate the gun system found in "Site-19 Roleplay" made by AdministratorGnar and ThunderGemios10

# This system includes almost all features of the gun system including ACTUAL Mobile support

# Inside the Settings inside "FirearmClient" (Client) there are currently in total of 2 Settings (will add more soon!)

```lua
local Settings = {
	ShowBlood = true, -- Show blood?
	ShowMuzzleEffects = true, -- Show muzzle?
}
```
# There are also 4 MORE Options inside FirearmServer (Server)

```lua
local Settings = {
	AlwaysDamage = false, -- Enabling this disables ALL team kill restrictions
	NotifyPlayer = true, -- Enable notifcations
	EnableGuiltySystem = true, -- Enable CD Guilty system
	
}
```

# If you want to make a certian tool hostile (upon equip CDS become hostile) scroll down on the tool until you reach Tags and click the + and add the tag called "Hostile"
![image](https://github.com/user-attachments/assets/9fff060b-f70c-4142-ae45-18b5eab518e0)


# Inside Replicated Storage You will find TWO Important modules called "TeamPriorityModule" and "Dictionary"

```lua
return {
	["Priority1"] = {"Class D", "Chaos Insurgency"}, --Class D and Hostile teams
	["Priority2"] = {"Security Department", "MTF Beta-7", "MTF Epsilon-11", "MTF Nu-7", "Intelligence Agency", "Scientific Department", "Medical Department","Janitor"}, -- Normal foundation teams
	["Priority3"] = {"RAISA", "Ethics Committee", "Site Director", "Administrative Department", "MTF Omega-1", "MTF Alpha-1","Internal Security Department"} -- TK Foundation teams
}
```
The module defines ALL Team kill restrictions so you can add all of your teams here

# Dictionary
![image](https://github.com/user-attachments/assets/c6be13cd-3345-494a-84c0-c1f85f184e0f)

This module is what defines the animations, stats etc for your gun (SOUNDS DONT DO ANYTHING YET!) this is required for you to make another table if you wish to add a custom gun



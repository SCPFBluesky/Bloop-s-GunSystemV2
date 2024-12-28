--[[
	Name: MedkitClass
	Author(s): @WATDAHECKLOL32
	Date: 2024-12-27 23:59:14
	RunTimeContext: Shared
	Information: Basic flux tool class example
]]

--!strict
--!native

--[[[

	So in order to create classes for my cheap flux tool handler
	The tool must have a string value ATTRIBUTE called Class
	with the value of the class the tool belongs too
	
	Each class module must have a function called Activated
	1st arg must always be "Tool"
	
	Very cheap way of doing it but it works well!
	
]]



--[[

You can also have Unequipped an Equipped functions.
These are optional and not required to in order to work.

@native function MedkitClass.Equipped(Tool: (Tool) )
	print("euqio")	
end;

@native function MedkitClass.Unequipped(Tool: (Tool))
	print("unequip")
end;

]]

local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread")

local Player = game:FindService("Players").LocalPlayer

local MedkitClass = {};

@native function MedkitClass.Activated(Tool: (Tool) )
	if not Tool then
		return;
	end;
	
	if Tool.Parent ~= Player.Character then
		return;
	end;
	
	network:FireServer("useMedkit", Tool)
end;

return MedkitClass;


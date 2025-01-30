--!nonstrict

--[[
	Author(s):		WATDAHECKLOL32
	Name:           MedkitClass.luau
	Info:           Handles medkits in the game.
	Date: 			1/30/24
	Run context:	Client
]]




local MedkitClass = {};

MedkitClass.__index = MedkitClass; -- create a new metamethod so we can call the important functions by using the metatable.
MedkitClass.__mode = "KV"; -- create a new 'weak' table

local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread")
local Player = game:FindService("Players").LocalPlayer;

local setmetatable = setmetatable; -- cache setmetatable to speed up things a little bit

--[[
    In order to create your tool with my flux tool handler your module must look like this and with 5 main functions
    .new (must be a constructer) :Activated :Deactivated() :Equip() :Unequip()
   
    Your tool must have a module called "Main", this module will be used to define what class the tool belongs tool, and passing the 'Variables' table to the .new
]]


function MedkitClass.new(Tool: (any), Vars: (any) ) -- vars is the 'Variables' table from the tool's 'Main' module.
    print(Vars) -- since the vars table was blank in our module, this will print an empty table unless you give it something.
    local medkitMeta = setmetatable({}, MedkitClass); -- create a new metatable, how i think of metatables (in this context) is giving each "Medkit" tool its own unquie table to each item. 
    
    medkitMeta.Tool = Tool
    medkitMeta.IsEquipped = false
    
    return medkitMeta; -- return the new metatable so we can use it later.
end;

function MedkitClass:Equip()
    self.IsEquipped = true -- 'self' refers to the current tool's metatablee
    
end;

function MedkitClass:Unequip()
    self.IsEquipped = false    
end;

function MedkitClass:Activated()
    if self.IsEquipped then
        network:FireServer("useMedkit", self.Tool) -- once the player activates the tool, we inform the server that the player has used a medkit
   end;
end;

function MedkitClass:Deactivated()
        -- since we dont have anything for medkits, we will leave this function blank for now.
end;


return MedkitClass;


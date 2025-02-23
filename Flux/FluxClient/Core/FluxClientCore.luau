--!nonstrict
--!native
--[[
	Author(s):		WATDAHECKLOL32
	Name:           FluxClientCore.luau
	Info:           Handles all Client aspects of the game.
	Date: 			2/14/24
	Run context:	Client
]]


print("[FLUX/CLIENT/CORE] FluxClientCore has been Loaded!")

---------------------------
--   V A R I A B L E S   --
---------------------------

local Import = require;
local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread");

local wait, delay, spawn, defer, cancel = task.wait, task.delay, task.spawn, task.defer, task.cancel;

local Random = Random.new();
local createAnimation = require("createAnimation");

local Lighting = game:FindService("Lighting");
local Debris = game:GetService("Debris");
local StarterGui = game:FindService("StarterGui");

local Players = game:FindService("Players");
local RunService = game:GetService("RunService");

local ReplicatedStorage = game:FindService("ReplicatedStorage");
local CollectionService = game:GetService("CollectionService");
local UserInputService = game:GetService("UserInputService");

local GuiService = game:GetService("GuiService");
local TweenService = game:GetService("TweenService");
local TeleportService = game:GetService("TeleportService");

local Classes = {
	FirearmClass = require("FirearmClass");
	CardClass = require("CardClass");
	MedkitClass = require("MedkitClass")
};

local RegisteredTools = {};

local Player = Players.LocalPlayer;
local Char = Player.Character or Player.CharacterAdded:Wait();

local InputHandler = require("InputHandler");

local GunConfig = require("GunConfig");
local Ambient = Lighting.Ambient;

local CurrentFirearm;
local FlashlightStatus = false;


local Notify = Player.PlayerGui:WaitForChild("Notifcation System").Message;
---------------------------
--      S E T U P        --
---------------------------


--------------------------------
-- F L U X  F U N C T I O N S --
--------------------------------

function InitTool(Tool: (Tool) )
	assert(Tool);
	
	if not Tool:IsA("Tool") then
		return;
	end;
	
	if RegisteredTools[Tool] then
		return;
	end;
	
	RegisteredTools[Tool] = true;

	if Tool:WaitForChild("Main") then
		local Main = Import(Tool.Main);
		local Variables = Main.Variables;

		local ToolClass = Classes[Main.Class].new(Tool, Variables); 

		Tool.Equipped:Connect(function()
			if ToolClass then
				ToolClass:Equip()
			end;

			if Main.Class == "FirearmClass" then
				CurrentFirearm = ToolClass;
			end;
		end);

		Tool.Unequipped:Connect(function()
			if ToolClass then
				ToolClass:Unequip()
			end;

			if Main.Class == "FirearmClass" then
				CurrentFirearm = nil;
			end;

		end);

		Tool.Activated:Connect(function()
			if ToolClass and Main.Class ~= "FirearmClass"  then
				ToolClass:Activated()
			end;
		end);

		Tool.Deactivated:Connect(function()
			if ToolClass and Main.Class ~= "FirearmClass" then
				ToolClass:Deactivated()
			end;
		end);
	end;
end;

function HandleCharAdded()
	for _,Tool: (Tool) in next, Player.Backpack:GetChildren() do
		if Tool:IsA("Tool") and not RegisteredTools[Tool] then
			InitTool(Tool)
		end;
	end;
	
	FlashlightStatus = false
	
	Player.Backpack.ChildAdded:Connect(function(NewTool: (Tool) )
		InitTool(NewTool)
	end);
end;



---------------------------------------------
-- N E T W O R K \ C O N N E C T I O N S  --
---------------------------------------------

InputHandler.Functions = {
	Holster = function(Down: (boolean), GPE: (boolean) )
		if GPE or not CurrentFirearm then
			return;
		end;
		
		if CurrentFirearm and Down then
			CurrentFirearm:Holster()
		end;
	end,
	
	Reload = function(Down: (boolean), GPE: (boolean) )
		if GPE or not CurrentFirearm then
			return;
		end;
		
		if Down then
			CurrentFirearm:Reload()
		end;
	end,
	
	Flashlight = function(Down: (boolean), GPE: (boolean) )
		if GPE then
			return;
		end;
		
		if Down then
			FlashlightStatus = not FlashlightStatus
			network:FireServer("useFlashlight", FlashlightStatus)
		end;
	end,
	
	Activate = function(Down: (boolean), GPE: (boolean) )
		if CurrentFirearm then
			spawn(function()
				CurrentFirearm:Activated(Down)
			end);
		end;
	end,
	
};



network:OnEvent({
	useNVG = function()
		Lighting.NightVisionEffect.Enabled = FlashlightStatus	
	end,
	
	ReplicateGunEffects = function(Weapon: (Tool), FireSound: (number), RayCast1: (Instance), Raycast2: (number) )
		Classes.FirearmClass.BulletEffects(Weapon, FireSound, RayCast1, Raycast2)
	end,

	NotifyPlayer = function(Msg: string)
		Notify.Text = Msg
		tween(Notify, {
			TextStrokeTransparency = 0;
			TextTransparency = 0;
		}, 1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		wait(6)
		tween(Notify, {
			TextStrokeTransparency = 1;
			TextTransparency = 1;
		}, 1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	end,
	
});

network:OnFunction({});



Player.CharacterAdded:Connect( function(character: Model) 
	HandleCharAdded()
end);

if Player.Character then
	HandleCharAdded()
end;


return {};

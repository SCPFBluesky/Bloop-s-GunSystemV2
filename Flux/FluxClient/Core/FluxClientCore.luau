--[[
	Name: FluxClientCore.Luau
	Author(s): @WATDAHECKLOL32
	Date: 2024-12-27 12:43:12 AM
	RunTimeContext: Shared
	Information: client side handler for the flux framework.
]]

--!strict
--!native


print("[FLUX/CLIENT/CORE] FluxClientCore has been Loaded!")

---------------------------
--   V A R I A B L E S   --
---------------------------

local NormalRequire = require;
local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread");

shared.RegisteredTools = {};

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

local Classes = script.Parent.Parent.Classes;
local Player = Players.LocalPlayer;
local Char = Player.Character or Player.CharacterAdded:Wait();

local NotifyMessageText = Player.PlayerGui:WaitForChild("Notifcation System").Message;

local ToolClass = require("ToolHandler");
local InputHandler = require("InputHandler");
local GunConfig = require("GunConfig");
local FirearmClass = require("FirearmClass");

local NotifyShown = false;
local Run = false;
local CanSprint = true;
local Ambient = Lighting.Ambient;
local MobileUI = Player.PlayerGui:WaitForChild("MobileUI")

local CurrentFirearm = nil;
---------------------------
--      S E T U P        --
---------------------------


local NotifcationTweens = {
	FadeIn = {};
	FadeOut = {}
};

do
	local NotifcationTweenInfo = TweenInfo.new(3.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, true)


	local FadeinTween = TweenService:Create(NotifyMessageText, NotifcationTweenInfo, {TextTransparency = 0})
	local FadeOutTween = TweenService:Create(NotifyMessageText, NotifcationTweenInfo, {TextTransparency = 1})

	table.insert(NotifcationTweens.FadeIn, FadeinTween)
	table.insert(NotifcationTweens.FadeOut, FadeOutTween)
end;

--------------------------------
-- F L U X  F U N C T I O N S --
--------------------------------

@native function InitTool(Tool: Tool)
	assert(Tool, "Attempt to call InitTool without a tool!")

	if Tool and Tool:HasTag("Firearm") then
		local Class;

		repeat
			task.wait()
			Class = FirearmClass.new(Tool)
		until Class and typeof(Class) == "table";

		if Class then
			--[[if CurrentFirearm and CurrentFirearm ~= Class then
				CurrentFirearm:Unequip()
			end;[[]]

			--[[if Tool.Parent == Player.Character then
				CurrentFirearm:Equip()
			end;]]

			Tool.Equipped:Once(@native function()
				CurrentFirearm = Class
				if CurrentFirearm == Class then
					CurrentFirearm:Equip()
				else
					task.wait()
					CurrentFirearm = Class
					CurrentFirearm:Equip()
				end;
			end);

			Tool.Unequipped:Once(@native function()
				if CurrentFirearm == Class then
					CurrentFirearm:Unequip()
					CurrentFirearm = nil
				end;
			end);
		end;
	end;

	do
		local Class = Tool:GetAttribute("Class");
		local ClassModule;

		if Class then
			ClassModule = require(Class)
		end;

		Tool:GetAttributeChangedSignal("Class"):Connect(@native function()
			Player:Kick("not smart enough!")
		end);

		Tool.Destroying:Connect(@native function()
			ToolClass.UnRegisterTool(Tool)
		end);

		Tool.Equipped:Connect(@native function(mouse: Mouse)
			if ClassModule and ClassModule.Equipped then
				ClassModule.Equipped(Tool)
			end;
		end);

		Tool.Unequipped:Connect(@native function()
			if ClassModule and ClassModule.Unequipped then
				ClassModule.Unequipped(Tool)
			end;
		end);

		Tool.Activated:Connect(@native function()
			if ClassModule then
				ClassModule.Activated(Tool)
			end;
		end);
	end;
end;

@native function HandleCharAdded()
	Player.Backpack.ChildAdded:Connect(@native function(child: Instance) 
		if child:IsA("Tool") then
			InitTool(child)	
		end;
	end);

	for _,v in Player.Backpack:GetChildren() do
		if v:IsA("Tool") then
			InitTool(v)
		end;
	end;

end;

--[[@native function OnRenderStep(DeltaTime: number)
	if Run and CanSprint then
		Char.Humanoid.WalkSpeed = 23
	else
		Char.Humanoid.WalkSpeed = 16
	end;
end;]]


---------------------------------------------
-- N E T W O R K \ C O N N E C T I O N S  --
---------------------------------------------

InputHandler.Functions = {
	Holster = @native function(Down: (boolean), GPE: (boolean))
		if Down and not GPE then
			CurrentFirearm:Holster()
		end;
	end,

	Reload = @native function(Down: (boolean), GPE: (boolean) )
		if CurrentFirearm and CurrentFirearm.Tool.Parent == Player.Character and not GPE then
			CurrentFirearm:Reload()
		end;
	end,

	Crawl = @native function(Down: (boolean), GPE: (boolean) )
		if Down and not GPE and CurrentFirearm then
			CurrentFirearm:Crawl()
		end;
	end,

	Activate = @native function(Down: (boolean), GPE: (boolean) )
		if not CurrentFirearm then
			return;
		end;

		if not Down then
			CurrentFirearm.MIN_BULLET_SPREAD_ANGLE = 0.4;
			CurrentFirearm.MAX_BULLET_SPREAD_ANGLE = 0.4;
			CurrentFirearm.SPREAD_INCREMENT = 1;
			CurrentFirearm.MAX_SPREAD_ANGLE = 10;
			CurrentFirearm.SpreadTime = {};
		end;

		if CurrentFirearm and CurrentFirearm.Tool.Parent == Player.Character and not GPE then
			task.spawn(@native function()
				CurrentFirearm.ButtonDown = Down
				CurrentFirearm:Fire()
			end);
		end;
	end,

	Drop = @native function(Down: (boolean), GPE: (boolean) )
		if CurrentFirearm and Down and not GPE then
			network:FireServer("dropFirearm", CurrentFirearm.Tool)
		end;
	end,


}


network:OnEvent({
	mkHitEffects = @native function(Action: string, gun: any, muzzlePos: Vector3, hitPos: Vector3, rayresult: any)
		FirearmClass:MKHitEffects(Action, muzzlePos, hitPos, rayresult, gun)
	end,


	NotifyPlayer = function(Msg: string)
		if NotifyShown then
			NotifyMessageText.Text = Msg
			return;
		end;

		NotifyShown = true
		NotifyMessageText.Text = Msg

		for _,v: (Tween) in NotifcationTweens.FadeIn do
			v:Play()
		end

		task.delay(9, @native function()
			for _,v: (Tween) in NotifcationTweens.FadeOut do
				v:Play()
				task.wait(v.TweenInfo.Time)
				NotifyShown = false
			end;
		end);

	end,

});
network:OnFunction({});


--RunService:BindToRenderStep("ClientRenderStep", 1, OnRenderStep)


Player.CharacterAdded:Connect(@native function(character: Model) 
	shared.RegisteredTools = {}
	HandleCharAdded()
end);

if Player.Character then
	shared.RegisteredTools = {}
	HandleCharAdded()
end;


return {};

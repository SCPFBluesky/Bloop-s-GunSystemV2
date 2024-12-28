--[[
	Name: FluxClientCore.Luau
	Author(s): @WATDAHECKLOL32
	Date: 2024-12-27 12:43:12 AM
	RunTimeContext: Shared
	Information: client side handler for the flux framework.
]]

--!strict
--!native

--[[
	network useage:
	network:Server(function, functionarg)
]]

print("[FLUX/CLIENT/CORE] FluxClientCore has been Loaded!")

---------------------------
--   V A R I A B L E S   --
---------------------------

local NormalRequire = require
local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread")

shared.RegisteredTools = {}

local Random = Random.new()
local createAnimation = require("createAnimation")

local Lighting = game:FindService("Lighting")
local Debris = game:GetService("Debris")
local StarterGui = game:FindService("StarterGui")

local Players = game:FindService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:FindService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local Classes = script.Parent.Parent.Classes
local Player = Players.LocalPlayer
local Char = Player.Character or Player.CharacterAdded:Wait()

local NotifyMessageText = Player.PlayerGui:WaitForChild("Notifcation System").Message
local ToolClass = require("ToolHandler")
local FirearmClass = require("FirearmClass")
local InputHandler = require("InputHandler")
local NotifyShown = false
local Run = false
local CanSprint = true

---------------------------
--      S E T U P        --
---------------------------




local NotifcationTweens = {
	FadeIn = {};
	FadeOut = {}
}

do
	local NotifcationTweenInfo = TweenInfo.new(3.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, true)


	local FadeinTween = TweenService:Create(NotifyMessageText, NotifcationTweenInfo, {TextTransparency = 0})
	local FadeOutTween = TweenService:Create(NotifyMessageText, NotifcationTweenInfo, {TextTransparency = 1})

	table.insert(NotifcationTweens.FadeIn, FadeinTween)
	table.insert(NotifcationTweens.FadeOut, FadeOutTween)
end

--------------------------------
-- F L U X  F U N C T I O N S --
--------------------------------


@native function HandleCharAdded()
	Player.Backpack.ChildAdded:Connect(@native function(child: Instance) 
		if child:IsA("Tool") then
			local Class = child:GetAttribute("Class")
			local ClassModule

			if Class then
				ClassModule = require(Class)
			end;

			ToolClass.RegisterTool(child)

			child.Destroying:Connect(@native function() 
				ToolClass.UnRegisterTool(child)
			end);

			child.Equipped:Connect(@native function(mouse: Mouse) 
				if ClassModule and ClassModule.Equipped then
					ClassModule.Equipped(child)
				end;
			end);

			child.Unequipped:Connect(@native function() 
				if ClassModule and ClassModule.Unequipped then
					ClassModule.Unequipped(child)
				end;
			end);

			child.Activated:Connect(@native function()						
				if ClassModule then
					ClassModule.Activated(child)
				end;
			end);
		end;	
	end)

	for _,v: Tool in Player.Backpack:GetChildren() do
		if v:IsA("Tool") then
			ToolClass.RegisterTool(v)

			v.Destroying:Connect(@native function() 
				ToolClass.UnRegisterTool(v)
			end)

			v.Activated:Connect(@native function()						
				if v:GetAttribute("Class") then
					local Class = v:GetAttribute("Class")
					if Class then
						local ClassModule = require(Class)
						ClassModule.Activated(v)
					end;
				end;
			end);
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
	Reload = @native function(Down: (boolean) , GPE: (boolean) )
		if not GPE then
			FirearmClass.Reload()
		end;
	end,
	Holster = @native function(Down: (boolean) , GPE: (boolean))
		if Down and not GPE then
			FirearmClass.Holster()
		end;
	end,
	Crawl = @native function(Down: (boolean), GPE: (boolean) )
		if Down and not GPE then
			FirearmClass.Crawl()
		end		
	end,
	
	Drop = @native function(Down: (boolean), GPE: (boolean) )
		if not GPE then
			FirearmClass.Drop()
		end		
	end,
}


network:OnEvent({
	mkHitEffects = @native function(Action: string, gun: any, muzzlePos, hitPos, rayresult)
		FirearmClass.mkHitEffects(Action, gun, muzzlePos, hitPos, rayresult)
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

})
network:OnFunction({})


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

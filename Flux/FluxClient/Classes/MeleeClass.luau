--//TODO: Rewrite this, this is bad.

--[[
	Name: Melee.luau
	Author(s): @WATDAHECKLOL32
	Date: 2024-12-29 02:43:58
	RunTimeContext: Shared
	Information: made at 4am
]]

--!strict

---------------------------
--   V A R I A B L E S   --
---------------------------

local OldRequire = require
local _Random = Random.new()

local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread")

local CreateAnimation = require("CreateAnimation")

local Player: (Player) = game:FindService("Players").LocalPlayer :: (Player)
local MeleeClass = {};

local _RaycastParams = RaycastParams.new()

do
	_RaycastParams.IgnoreWater = true
	_RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	_RaycastParams.CollisionGroup = "Bullets"
end;

local IsEquipped = false;
local DB: (boolean) = false :: boolean

type Animations = {
	Idle : AnimationTrack?;
	Slash: AnimationTrack?;
	Slash2: AnimationTrack?;
	Slash3: AnimationTrack?
}

local Animations: Animations = {
	Idle = nil;
	Slash = nil;
	Slash2 = nil;
	Slash3 = nil

}

---------------------------
-- C L A S S F U N C T I O N S --
---------------------------

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  AnimationControl
	 @Author :        @WATDAHECKLOL32
	 @Description :   Handles Animations
	 @Params : 	      String: AnimationName - Name of the animation to play, Number? : Speed - The speed of the animation String: Arg - State control "Play"/"Stop"
	--------------------------------------------------------------------------------------------------
--]]
 function MeleeClass:AnimationControl(AnimationName: (string) , Speed: (number?), Arg: (string) )
	if not IsEquipped then
		return;
	end;
	
	local Char: (any) = Player.Character or Player.CharacterAdded:Wait() :: (any)
	
	do
		assert(AnimationName, "Attempt to call AnimationControl without a name.");
		assert(Arg, "Attempt to call AnimationControl without an Arg.")
		
		if not Speed then
			Speed = 0.2
		end;
		
	end;
	
	if Animations[AnimationName] and Arg == "Play" then
		if Char and Char:FindFirstChild("Humanoid") and Char.Humanoid.Health > 0 then
			Animations[AnimationName]:Play(Speed)
		end;
		
	elseif Arg == "Stop" then
		Animations[AnimationName]:Stop(Speed)
	end;
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Activated
	 @Author :        @WATDAHECKLOL32
	 @Description :   Use function, gets called by the ToolHandler system
	 @Params : 	      Tool : Tool - The Melee
	--------------------------------------------------------------------------------------------------
--]]
 function MeleeClass.Activated(Tool : (any) )
	assert(Tool, "[MeleeClass] Attempt to call Activated but no tool was passed.")
	local Char: (any) = Player.Character or Player.CharacterAdded:Wait() :: (any)
	
	if DB or Tool.Parent ~= Char or Char.Humanoid.Health <= 0 or not Char:FindFirstChild("HumanoidRootPart") or not IsEquipped then
		return;
	end;
	
	_RaycastParams.FilterDescendantsInstances = {Char, workspace.CurrentCamera}
	
	local doomPos = Char.HumanoidRootPart.CFrame.Position
	local HRPlookvec = Char.HumanoidRootPart.CFrame.LookVector 
	local Doom = workspace:Raycast(doomPos, HRPlookvec * 5, _RaycastParams)
	
	local RayResult = {
		Instance = Doom and Doom.Instance;
		Normal = Doom and Doom.Normal;
		Position = Doom and Doom.Position
	}


	local RandomSlash

	local SlashIndex: {string} = {"Slash", "Slash2", "Slash3"} :: {string}
	local Num: (number) = _Random:NextInteger(1, 3) :: (number)
	
	local RandomSlash: (any) = SlashIndex[Num] :: (any)

	
	if IsEquipped then
		MeleeClass:AnimationControl(RandomSlash, 0.2, "Play")
	end;
	
	network:FireServer("useMelee", Tool, RayResult)
	
	DB = true
		
	task.delay(1.5,  function()
		DB = false
		RandomSlash = nil
	end);	
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Equipped
	 @Author :        @WATDAHECKLOL32
	 @Description :   Equipped function, gets called by the ToolHandler system
	 @Params : 	      Tool : Tool - The Melee
	--------------------------------------------------------------------------------------------------
--]]
 function MeleeClass.Equipped(Tool: (Tool) )
	assert(Tool, "[MeleeClass] Attempt to call Equipped but no tool was passed.")
	
	if IsEquipped then
		return;
	end;
	
	IsEquipped = true
	
	if Animations.Idle and Animations.Idle.IsPlaying then
		Animations.Idle:Stop()
	end;
	
	local Char: (any) = Player.Character or Player.CharacterAdded:Wait() :: (any)

	local Animator = Char:WaitForChild("Humanoid").Animator

	if not Tool:GetAttribute("Inited") then
		Tool:SetAttribute("Inited", true)
		network:FireServer("createKnifeSounds", Tool)
	end;
	
	local MeleeSettings: (ModuleScript) = Tool:FindFirstChild("Main") :: (ModuleScript)
	
	local MainModule: any = OldRequire(MeleeSettings) :: any
	
	for Name : (string) , SoundID: (number) in MainModule.Animations do
		local New = CreateAnimation.new(Animator, SoundID)

		Animations[Name] = New
	end;
	
	if IsEquipped then
		MeleeClass:AnimationControl("Idle", 0.2, "Play")
	end;
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Unequipped
	 @Author :        @WATDAHECKLOL32
	 @Description :   Unequipped function, gets called by the ToolHandler system
	 @Params : 	      Tool : Tool - The Melee
	--------------------------------------------------------------------------------------------------
--]]
 function MeleeClass.Unequipped(Tool: (Tool) )	
	assert(Tool, "[MeleeClass] Attempt to call Unequipped but no tool was passed.")
	if not IsEquipped then
		return;
	end;
	IsEquipped = false
	
	if not IsEquipped then
		for _,v: (any) in Animations do
			v:Stop()
		end;
	end;
end;



return MeleeClass;

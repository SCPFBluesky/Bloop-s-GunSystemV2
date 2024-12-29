--[[
	Name: Melee.luau
	Author(s): @WATDAHECKLOL32
	Date: 2024-12-29 02:43:58
	RunTimeContext: Shared
	Information: made at 4am
]]
--!strict
--!native
task.wait(1)

local OldRequire = require
local _Random = Random.new()

local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread")

local CreateAnimation = require("CreateAnimation")

local Player: (Player) = game:FindService("Players").LocalPlayer :: (Player)

local Char: (any) = Player.Character or Player.CharacterAdded:Wait() :: (any)
local Animator: (Animator) = Char:WaitForChild("Humanoid").Animator :: Animator
local MeleeClass = {};

local _RaycastParams = RaycastParams.new()

do
	_RaycastParams.IgnoreWater = true
	_RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	_RaycastParams.CollisionGroup = "Bullets"
end;

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

@native function MeleeClass:AnimationControl(AnimationName: (string) , Speed: (number?), Arg: (string) )
	do
		assert(AnimationName, "Attempt to call AnimationControl without a name.");
		assert(Arg, "Attempt to call AnimationControl without an Arg.")
		
		if not Speed then
			Speed = 0.2
		end;
		
	end;
	
	if Animations[AnimationName] and Arg == "Play" then
		-- warn("omg yes pla")
		Animations[AnimationName]:Play(Speed)
	elseif Arg == "Stop" then
		Animations[AnimationName]:Stop(Speed)
	end;
end;

@native function MeleeClass.Activated(Tool : (any) )
	assert(Tool, "[MeleeClass] Attempt to call Activated but no tool was passed.")
	
	if DB or Tool.Parent ~= Char or Char.Humanoid.Health <= 0 then
		return;
	end;
	
	_RaycastParams.FilterDescendantsInstances = {Char}
	
	local Head: (BasePart) = Char.Head :: (BasePart)
	local HeadPos: (Vector3) = Head.Position :: (Vector3) 
	local direction: (Vector3) = Head.CFrame.LookVector :: (Vector3)
	local Doom = workspace:Raycast(HeadPos, direction * 4.7, _RaycastParams)
	
	local RayResult = {
		Instance = Doom and Doom.Instance or nil;
		Normal = Doom and Doom.Normal or nil;
		Position = Doom and Doom.Position
	}


	local RandomSlash

	local SlashIndex: {string} = {"Slash", "Slash2", "Slash3"} :: {string}
	local Num: (number) = _Random:NextInteger(1, 3) :: (number)
	
	local RandomSlash: (any) = SlashIndex[Num] :: (any)

	
	MeleeClass:AnimationControl(RandomSlash, 0.2, "Play")
	network:FireServer("useMelee", Tool, RayResult)
	
	DB = true
		
	task.delay(1.5, @native function()
		DB = false
		RandomSlash = nil
	end);
		
end;

@native function MeleeClass.Equipped(Tool: (Tool) )
	assert(Tool, "[MeleeClass] Attempt to call Equipped but no tool was passed.")
	
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
	
	
	task.delay(0.1, @native function()
		MeleeClass:AnimationControl("Idle", 0.2, "Play")
	end);
end;

@native function MeleeClass.Unequipped(Tool: (Tool) )
	assert(Tool, "[MeleeClass] Attempt to call Unequipped but no tool was passed.")

	for _,ActiveTracks: (any) in Animations do
		ActiveTracks:Stop()
	end;
	
	
end;

return MeleeClass;

--!strict
--!native
--[[
	Author(s):		WATDAHECKLOL32
	Name:           FirearmClass.luau
	Info:           Handles client aspect of the gun system.
	Date: 			2/14/24
	Run context:	Client
]]


local FirearmClass = {};

FirearmClass.__index = FirearmClass;
FirearmClass.__mode = "KV";

local game, assert = game, assert;
local wait = task.wait;

local include = shared.import;
local network = include("network");

local Players = game:FindService("Players");
local Player = Players.LocalPlayer;

local require, tagged = include("require", "tagged");
local setmetatable = setmetatable;

local CreateAnimation = require("CreateAnimation");
local AnimationTimer = 0.2;

local RayParmas = RaycastParams.new();
RayParmas.FilterType = Enum.RaycastFilterType.Exclude;

local Mouse = Player:GetMouse();
local EffectsFolder = game:FindService("ReplicatedStorage").FirearmShared.Stuff;

local Debris = game:FindService("Debris");
local Terrain = workspace.Terrain;

local MobileGUI = Player.PlayerGui:WaitForChild("MobileUI");
local DebounceRate = 0;

local UserInputService = game:FindService("UserInputService");
local RunService = game:FindService("RunService");

local function getIgnorelist(items: ({Instance?}) )
	local ignore = tagged("RayIgnore")
	for _, object: (Instance?) in next, items do
		table.insert(ignore, 1, object)
	end;
	return ignore;
end;

function FirearmClass.BulletEffects(Weapon: (any) , FireSound: (number), RayResult1: (any), RayResult2: (any) )
	local Sound = Instance.new("Sound");
	Sound.Name = "Discharge"
	Sound.SoundId =  "rbxassetid://"..FireSound
	Sound.Parent = Weapon.Handle
	
	
	Sound:Play()
	
	for _, Effect in next, EffectsFolder.Muzzle:GetChildren() do
		local clone = Effect:Clone()
		clone.Parent = Weapon.Handle.Muzzle
		local DestructionTime
		if clone:IsA("ParticleEmitter") then
			clone:Emit(20)
		end;
		if clone.Name == "Light" then
			DestructionTime = 0.1
		else
			DestructionTime = 5
		end;
		Debris:AddItem(clone, DestructionTime)
	end;
	
	Debris:AddItem(Sound, Sound.TimeLength)
	
	if RayResult1 and RayResult2 then
		local EffectPart = EffectsFolder.Effects.Effects:Clone();
		EffectPart.Parent = Terrain
		EffectPart.CFrame = EffectPart.CFrame:ToObjectSpace(CFrame.new(RayResult2, Weapon.Handle.Muzzle.WorldPosition))
		
		if RayResult1.Parent and RayResult1.Parent:FindFirstChildWhichIsA("Humanoid") then
			EffectPart.Blood:Emit(10)
			EffectPart.Hit:Play()
		else
			EffectPart.Flash:Emit(10)
			EffectPart.Smoke:Emit(10)
		end;
		
		Debris:AddItem(EffectPart, 0.6)
	end;
end;

function FirearmClass.new(Weapon: (Tool), Data: (any) )
	assert(Weapon);
	assert(Data);
	
	local Animator: (Animator) = Player.Character:WaitForChild("Humanoid").Animator;
	local self = setmetatable({}, FirearmClass);
	
	self.Tool = Weapon;
	self.Equipped = false;
	
	self.IsHolstered = false;
	self.IsReloading = false;
	
	self.Settings = Data;
	self.MouseDown = false;
	
	self.MaxAmmo = self.Settings.Ammo
	self.Ammo = self.Settings.Ammo;
	
	self.Spread = self.Settings.Spread;
	self.SpreadGuide = 0;
	
	self.Animations = {
		Idle = CreateAnimation.new(Animator, self.Settings.Animations.Idle);
		Holster = CreateAnimation.new(Animator, self.Settings.Animations.Lower);
		Reload = CreateAnimation.new(Animator, self.Settings.Animations.Reload)
	};
	

	network:FireServer("createGun", self.Tool);
	
	RayParmas.FilterDescendantsInstances = getIgnorelist({Player.Character, workspace.CurrentCamera});
	return self;
end;

function FirearmClass:Equip()
	self.Equipped = true
	
	self.IsHolstered = false
	self.IsReloading = false
	
	if self.Tool.Parent == Player.Character and self.Animations and self.Animations.Idle then
		self.Animations.Idle:Play(AnimationTimer)
	end;
	
	if game:FindService("UserInputService").TouchEnabled then
		MobileGUI.Enabled = true
	end;
end;

function FirearmClass:Reload()
	if self.Ammo == self.MaxAmmo or self.IsHolstered or self.IsReloading or self.Tool.Parent ~= Player.Character then
		return;
	end;
	
	self.IsReloading = true
	
	if self.Tool.Parent == Player.Character then
		self.Ammo = 0
		self.Animations.Reload:Play(AnimationTimer)
		
		network:FireServer("replicateReload", self.Tool)
		wait(self.Animations.Reload.Length);
		
		if self.Tool.Parent == Player.Character then
			self.Ammo = self.MaxAmmo
			self.IsReloading = false
		end;
	end;
end;

function FirearmClass:Unequip()
	self.Equipped = false

	self.IsHolstered = false
	self.IsReloading = false
	
	if game:FindService("UserInputService").TouchEnabled then
		MobileGUI.Enabled = true
	end;
	
	if self.Tool.Parent ~= Player.Character then
		for _, Animation: (AnimationTrack) in next, self.Animations do
			Animation:Stop(AnimationTimer)
		end;
	end;
end;

function FirearmClass:Holster()
	if not self.Equipped or self.IsReloading then
		return;
	end;
	
	self.IsHolstered = not self.IsHolstered
		
	if self.IsHolstered then
		self.Animations.Holster:Play()
	else
		self.Animations.Holster:Stop()
	end;
end;

function FirearmClass:Activated(Down: (boolean) )
	if not self.Equipped or self.IsReloading or self.IsHolstered or self.Ammo <= 0 then
		return;
	end;
	
	self.MouseDown = Down
	
	if not Down then
		self.Spread = self.Settings.Spread	
		self.SpreadGuide = 0
	end;
	
	while self.MouseDown and not self.IsHolstered and self.Equipped and not self.IsReloading and self.Ammo > 0 and Player and Player.Character and Player.Character:FindFirstChild("Head") and Player.Character:FindFirstChildWhichIsA("Humanoid") and Player.Character.Humanoid.Health > 0 and Player.Character:FindFirstChild("HumanoidRootPart") do	
		if os.clock() - DebounceRate < self.Settings.RPM then
			return;
		end;

		DebounceRate = os.clock()

		self.SpreadGuide += 0.3
		self.Ammo -= 1

		local MouseRay = Mouse.UnitRay;
		local MouseOrigin = MouseRay.Origin;
		local MouseDirection = MouseRay.Direction;

		local MouseHit, MouseHitPosition = workspace:FindPartOnRayWithIgnoreList(
			Ray.new(MouseOrigin, MouseDirection * 1000),
			getIgnorelist({workspace.CurrentCamera, Player.Character}),
			false,
			true
		);

		local TargetPosition = MouseHitPosition or (MouseOrigin + MouseDirection * 1000);

		local RayOrigin = Player.Character.Head.Position;
		local DirectionToTarget = (TargetPosition - RayOrigin).Unit;

		local SpreadResult = self.SpreadGuide * self.Spread / 5;
		local spreadX = math.rad(math.random(-SpreadResult * 100, SpreadResult * 100) / 100);
		local spreadY = math.rad(math.random(-SpreadResult * 100, SpreadResult * 100) / 100);
		local spreadZ = math.rad(math.random(-SpreadResult * 100, SpreadResult * 100) / 100);

		local FinalDir = (CFrame.new(Vector3.new(), DirectionToTarget) * CFrame.Angles(spreadX, spreadY, spreadZ)).LookVector;

		local Raycast1, Raycast2 = workspace:FindPartOnRayWithIgnoreList(
			Ray.new(RayOrigin, FinalDir * 100),
			getIgnorelist({workspace.CurrentCamera, Player.Character}),
			false,
			true
		);

		FirearmClass.BulletEffects(self.Tool, self.Settings.Sounds.Fire, Raycast1, Raycast2)
		network:FireServer("dischargeFirearm", self.Tool, self.Settings.Sounds.Fire, Raycast1, Raycast2);



		if not self.Settings.Automatic then
			break;
		end;

		wait(self.Settings.RPM)
	end;
	
	self.Spread = self.Settings.Spread	
	self.SpreadGuide = 0
end;

return FirearmClass;
